import { fail } from "../domain/contracts.ts";
import { env } from "../infra/config.ts";
import {
  adminClient,
  deleteIdentity,
  deletionPending,
  drainAssets,
  listPhotoNames,
  removePhotoNames,
  rpc,
  type Session,
} from "../infra/supabase.ts";

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
  for (let pass = 0; pass < 7; pass++) {
    const names = await listPhotoNames(admin, uid);
    if (names === null) {
      return fail(
        "STORAGE_PENDING",
        "PlateWise could not check your photos. Deletion is pending and can be resumed.",
        503,
        true,
      );
    }
    if (names.length === 0) {
      const final = await rpc<{ delete_account: boolean }>(admin, "pw_delete_finalize", {
        p_user: uid,
        p_account: requestAccount,
      });
      if (final.delete_account && !await deleteIdentity(admin, uid)) {
        return fail(
          "ACCOUNT_DELETE_PENDING",
          "Your data was removed. Account removal is still pending. Resume deletion in Settings.",
          503,
          true,
        );
      }
      return { deleted: true, account_deleted: final.delete_account };
    }
    if (!await removePhotoNames(admin, uid, names)) {
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
  if (await deletionPending(session.client)) {
    fail("DELETION_PENDING", "Data deletion is pending. Resume it in Settings.", 409, true);
  }
}
