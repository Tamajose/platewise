import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { fail, ownedPath, validateImage } from "../domain/contracts.ts";
import { stripImageMetadata } from "../domain/media.ts";
import type { ImageInput } from "../domain/ports.ts";
import { env } from "./config.ts";

export const bucket = "meal-media";
const configuration = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };

/** A client that can bypass row-level security. Only for owner-scoped writes. */
export function adminClient() {
  const url = env("SUPABASE_URL");
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return fail("BACKEND_CONFIG", "PlateWise is temporarily unavailable.", 503, true);
  return createClient(url, key, configuration);
}

/** Checks the caller's token with Supabase Auth and builds their session. */
export async function authenticate(request: Request) {
  const token = request.headers.get("Authorization")?.match(/^Bearer (\S+)$/i)?.[1];
  if (!token) return fail("SESSION_REQUIRED", "Your session has expired. Sign in to continue.", 401);
  const url = env("SUPABASE_URL");
  const publicKey = env("SUPABASE_PUBLISHABLE_KEY") ?? env("SUPABASE_ANON_KEY");
  if (!url || !publicKey) return fail("BACKEND_CONFIG", "PlateWise is temporarily unavailable.", 503, true);
  const client = createClient(url, publicKey, {
    ...configuration,
    global: { headers: { Authorization: "Bearer " + token } },
  });
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    return fail("SESSION_REQUIRED", "Your session has expired. Sign in to continue.", 401);
  }
  return { uid: data.user.id, client, admin: adminClient() };
}
export type Session = Awaited<ReturnType<typeof authenticate>>;

/** Translates a database error into the API's error codes. */
export function dataError(error: { code?: string; message?: string }): never {
  if (error.message === "NOT_FOUND") return fail("NOT_FOUND", "That entry is unavailable.", 404);
  if (error.message === "STORAGE_PENDING") {
    return fail("STORAGE_PENDING", "Photo deletion is pending. Resume it in Settings.", 503, true);
  }
  if (error.message === "DELETION_PENDING") {
    return fail("DELETION_PENDING", "Data deletion is still pending. Resume it in Settings.", 409, true);
  }
  if (error.message === "STALE_MEAL" || error.message === "STALE_WATER") {
    return fail("STALE_EDIT", "This entry has changed. Refresh the log and reopen it.", 409);
  }
  if (error.message === "INVALID_TIMEZONE") {
    return fail("INVALID_TIMEZONE", "Enter a supported IANA timezone.");
  }
  if (error.message === "CONSENT_REQUIRED") {
    return fail("CONSENT_REQUIRED", "Correction sharing is off for this account.", 403);
  }
  if (error.code === "23505") {
    return fail("CONFLICT", "That entry already exists or the photo is attached to another meal.", 409);
  }
  if (error.code === "23514" || error.code === "22003") {
    return fail("VALIDATION", "One or more values are outside the supported range.");
  }
  return fail("DATA_UNAVAILABLE", "Your data could not be updated or loaded. Try again.", 503, true);
}

/** Calls a database function and returns its result, or throws an API error. */
export async function rpc<T>(
  client: SupabaseClient,
  name: string,
  args?: Record<string, unknown>,
): Promise<T> {
  const { error, data } = await client.rpc(name, args);
  if (error) dataError(error);
  return data as T;
}

/** Downloads one of the caller's own photos, checks it and removes its metadata. */
export async function privateImage(session: Session, path: string): Promise<ImageInput> {
  ownedPath(path, session.uid);
  const { data, error } = await session.client.storage.from(bucket).download(path);
  if (error || !data) return fail("NOT_FOUND", "That photo is unavailable.", 404);
  if (data.size > 5 * 1024 * 1024) fail("IMAGE_SIZE", "Choose an image up to 5 MB.");
  const bytes = new Uint8Array(await data.arrayBuffer());
  const mime = validateImage(bytes, path);
  return { bytes: stripImageMetadata(bytes, mime), mime };
}

/** Deletes photos from storage and clears their cleanup jobs. */
export async function drainAssets(admin: SupabaseClient, paths: string[]) {
  if (paths.length === 0) return;
  const { error } = await admin.storage.from(bucket).remove(paths);
  if (error) {
    fail(
      "STORAGE_CLEANUP",
      "The log was removed. Its photo cleanup is pending. Retry in Settings or Today.",
      503,
      true,
    );
  }
  const { error: clearError } = await admin.from("asset_jobs").delete().in("path", paths);
  if (clearError) {
    fail("STORAGE_CLEANUP", "Photo cleanup still needs confirmation. Retry in Settings or Today.", 503, true);
  }
}

/** Whether a data deletion is waiting to be finished for the caller. */
export async function deletionPending(client: SupabaseClient): Promise<boolean> {
  const { data, error } = await client.from("deletion_jobs").select("user_id").maybeSingle();
  if (error) dataError(error);
  return data !== null;
}

/** Paths of photos whose deletion still needs to be confirmed. */
export async function pendingCleanupPaths(client: SupabaseClient): Promise<string[]> {
  const { data, error } = await client.from("asset_jobs").select("path").limit(100);
  if (error) dataError(error);
  return (data ?? []).map((row) => row.path as string);
}

/** A short-lived link to the photo of one of the caller's meals. */
export async function signedPhotoUrl(client: SupabaseClient, uid: string, mealId: string) {
  const { data: row, error } = await client.from("meals").select("image_storage_path").eq("id", mealId)
    .maybeSingle();
  if (error) dataError(error);
  if (!row?.image_storage_path) return fail("NOT_FOUND", "That photo is unavailable.", 404);
  const path = ownedPath(row.image_storage_path, uid);
  const { data, error: signingError } = await client.storage.from(bucket).createSignedUrl(path, 90);
  if (signingError || !data) return fail("NOT_FOUND", "That photo is unavailable.", 404);
  return { signed_url: data.signedUrl, expires_in: 90 };
}

/** File names in a person's photo folder, or null when storage could not be read. */
export async function listPhotoNames(admin: SupabaseClient, uid: string): Promise<string[] | null> {
  const { data, error } = await admin.storage.from(bucket).list(uid, {
    limit: 100,
    offset: 0,
    sortBy: { column: "name", order: "asc" },
  });
  return error ? null : data.map((entry) => entry.name);
}

/** Removes photos from a person's folder. Returns false when storage refused. */
export async function removePhotoNames(admin: SupabaseClient, uid: string, names: string[]) {
  const { error } = await admin.storage.from(bucket).remove(names.map((name) => uid + "/" + name));
  return !error;
}

/** Removes the sign-in identity. Returns false when the auth service refused. */
export async function deleteIdentity(admin: SupabaseClient, uid: string) {
  const { error } = await admin.auth.admin.deleteUser(uid, false);
  return !error;
}
