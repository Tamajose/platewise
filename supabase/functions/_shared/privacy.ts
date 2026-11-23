import { fail } from "./contracts.ts";
import { adminClient, bucket, dataError, drainAssets, env, rpc, type Session } from "./http.ts";

export async function erase(session: Session, requestAccount: boolean) {
  const { uid, admin } = session;
  const job = await rpc<{ delete_account: boolean }>(admin, "pw_delete_begin", {
    p_user: uid,
    p_account: requestAccount,
  });
  if (job.delete_account && !requestAccount) {
    return fail(
      "DELETION_PENDING",
      "An account deletion is already pending. Resume account deletion in Settings.",
      409,
      true,
    );
  }
  const storage = admin.storage.from(bucket);
  for (let pass = 0; pass < 7; pass++) {
    const { data, error } = await storage.list(uid, {
      limit: 100,
      offset: 0,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) {
      return fail(
        "STORAGE_PENDING",
        "PlateWise could not check your photos. Deletion is pending and can be resumed.",
        503,
        true,
      );
    }
    if (data.length === 0) {
      const final = await rpc<{ delete_account: boolean }>(admin, "pw_delete_finalize", {
        p_user: uid,
        p_account: requestAccount,
      });
      if (final.delete_account) {
        const { error: authError } = await admin.auth.admin.deleteUser(uid, false);
        if (authError) {
          return fail(
            "ACCOUNT_DELETE_PENDING",
            "Your data was removed. Account removal is still pending. Resume deletion in Settings.",
            503,
            true,
          );
        }
      }
      return { deleted: true, account_deleted: final.delete_account };
    }
    const { error: removeError } = await storage.remove(data.map((item) => uid + "/" + item.name));
    if (removeError) {
      return fail(
        "STORAGE_PENDING",
        "PlateWise could not remove every photo. Deletion is pending and can be resumed.",
        503,
        true,
      );
    }
  }
  return fail("STORAGE_PENDING", "There are more photos to remove. Resume deletion in Settings.", 503, true);
}

async function equalSecrets(a: string, b: string) {
  const hash = async (value: string) =>
    new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
  const [x, y] = await Promise.all([hash(a), hash(b)]);
  let unequal = 0;
  for (let i = 0; i < x.length; i++) unequal |= x[i] ^ y[i];
  return unequal === 0;
}
export async function cleanup(request: Request) {
  const configured = env("PLATEWISE_CLEANUP_SECRET");
  const sent = request.headers.get("x-platewise-cleanup") ?? "";
  if (!configured || configured.length < 24 || sent.length > 200 || !await equalSecrets(sent, configured)) {
    return fail("SESSION_REQUIRED", "Cleanup authorization is required.", 401);
  }
  const admin = adminClient();
  const paths = await rpc<string[]>(admin, "pw_sweep");
  await drainAssets(admin, paths);
  return { removed_count: paths.length };
}

export async function assertAvailable(session: Session) {
  const { data, error } = await session.client.from("deletion_jobs").select("user_id").maybeSingle();
  if (error) dataError(error);
  if (data) fail("DELETION_PENDING", "Data deletion is pending. Resume it in Settings.", 409, true);
}
