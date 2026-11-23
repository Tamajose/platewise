import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { ApiError, fail, ownedPath, validateImage } from "./contracts.ts";
import { type ImageInput, OpenAIProvider, providerConfig } from "./providers.ts";

export const env = (key: string) => Deno.env.get(key);
export const provider = new OpenAIProvider(providerConfig(env));
export const bucket = "meal-media";
const configuration = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };

export function adminClient() {
  const url = env("SUPABASE_URL");
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return fail("BACKEND_CONFIG", "PlateWise is temporarily unavailable.", 503, true);
  return createClient(url, key, configuration);
}

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

export async function readLimited(request: Request, limit: number) {
  if (Number(request.headers.get("Content-Length") ?? 0) > limit) {
    fail("SIZE_LIMIT", "This upload is larger than the supported limit.", 413);
  }
  const reader = request.body?.getReader();
  if (!reader) return new Uint8Array();
  const parts: Uint8Array[] = [];
  let length = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.length;
    if (length > limit) {
      await reader.cancel();
      return fail("SIZE_LIMIT", "This upload is larger than the supported limit.", 413);
    }
    parts.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) {
    bytes.set(part, offset);
    offset += part.length;
  }
  return bytes;
}

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
export async function rpc<T>(
  client: SupabaseClient,
  name: string,
  args?: Record<string, unknown>,
): Promise<T> {
  const { error, data } = await client.rpc(name, args);
  if (error) dataError(error);
  return data as T;
}

export async function privateImage(session: Session, path: string): Promise<ImageInput> {
  ownedPath(path, session.uid);
  const { data, error } = await session.client.storage.from(bucket).download(path);
  if (error || !data) return fail("NOT_FOUND", "That photo is unavailable.", 404);
  if (data.size > 5 * 1024 * 1024) fail("IMAGE_SIZE", "Choose an image up to 5 MB.");
  const bytes = new Uint8Array(await data.arrayBuffer());
  const mime = validateImage(bytes, path);
  return { bytes: stripImageMetadata(bytes, mime), mime };
}

// The mobile app transcodes images. Direct API clients may upload other supported formats.
export function stripImageMetadata(bytes: Uint8Array, mime: string) {
  if (mime === "image/jpeg") return stripJpegMetadata(bytes);
  const png = mime === "image/png";
  const header = png ? 8 : 12;
  const kept = png
    ? new Set(["IHDR", "PLTE", "IDAT", "IEND", "tRNS", "sRGB", "gAMA", "cHRM"])
    : new Set(["VP8X", "VP8 ", "VP8L", "ALPH"]);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const clean = new Uint8Array(bytes.length);
  clean.set(bytes.subarray(0, header));
  let written = header;
  let hasImage = false;
  let ended = false;
  for (let offset = header; offset + (png ? 12 : 8) <= bytes.length;) {
    const kindAt = offset + (png ? 4 : 0);
    const kind = String.fromCharCode(...bytes.subarray(kindAt, kindAt + 4));
    const length = view.getUint32(offset + (png ? 0 : 4), !png);
    const end = offset + length + (png ? 12 : 8 + Number(length % 2 !== 0));
    if (end > bytes.length || kind === "ANIM" || kind === "ANMF") {
      return fail("IMAGE_TYPE", "Choose a readable, still JPEG, PNG or WebP.");
    }
    if (kept.has(kind)) {
      clean.set(bytes.subarray(offset, end), written);
      if (kind === "VP8X" && length === 10) clean[written + 8] &= 0x10;
      written += end - offset;
    }
    hasImage ||= kind === "IDAT" || kind === "VP8 " || kind === "VP8L";
    offset = end;
    if (kind === "IEND" || offset === bytes.length) {
      ended = !png || kind === "IEND";
      break;
    }
  }
  if (!hasImage || !ended) return fail("IMAGE_TYPE", "This picture could not be read. Choose another image.");
  if (!png) new DataView(clean.buffer).setUint32(4, written - 8, true);
  return clean.subarray(0, written);
}

export function stripJpegMetadata(bytes: Uint8Array) {
  const result = new Uint8Array(bytes.length);
  result.set(bytes.subarray(0, 2));
  let read = 2;
  let write = 2;
  while (read + 3 < bytes.length && bytes[read] === 0xff) {
    const marker = bytes[read + 1];
    if (marker === 0xda) {
      result.set(bytes.subarray(read), write);
      return result.subarray(0, write + bytes.length - read);
    }
    const length = bytes[read + 2] * 256 + bytes[read + 3];
    const end = read + length + 2;
    if (length < 2 || end > bytes.length) break;
    if (!(marker >= 0xe0 && marker <= 0xef) && marker !== 0xfe) {
      result.set(bytes.subarray(read, end), write);
      write += end - read;
    }
    read = end;
  }
  return fail("IMAGE_TYPE", "This JPEG could not be read. Choose another image.");
}

export async function reserve(session: Session) {
  if (!provider.config.key || provider.config.kind !== "openai") {
    fail("AI_UNAVAILABLE", "Live analysis has not been configured. You can enter the meal manually.", 503);
  }
  const booked = await rpc<boolean>(session.admin, "pw_claim_ai", {
    p_user: session.uid,
    p_units: 2,
    p_limit: 40,
  });
  if (!booked) {
    fail("RATE_LIMIT", "You’ve reached today’s analysis limit. You can keep logging meals manually.", 429);
  }
}

async function sha(value: Uint8Array | string): Promise<string> {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : Uint8Array.from(value);
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return Array.from(hash, (b) => b.toString(16).padStart(2, "0")).join("");
}
export async function cached<T>(
  session: Session,
  action: string,
  seed: Uint8Array | string,
  work: () => Promise<T>,
) {
  const startedAt = new Date().toISOString();
  const key = await sha(
    JSON.stringify([
      1,
      action,
      provider.config.kind,
      provider.config.vision,
      provider.config.text,
      await sha(seed),
    ]),
  );
  const { data, error } = await session.admin.from("ai_cache").select("data")
    .eq("user_id", session.uid).eq("cache_key", key).gt("expires_at", new Date().toISOString()).maybeSingle();
  if (error) dataError(error);
  if (data) return data.data as T;
  await reserve(session);
  const result = await work();
  await rpc(session.admin, "pw_store_ai", {
    p_user: session.uid,
    p_key: key,
    p_data: result,
    p_started_at: startedAt,
  });
  return result;
}
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
export function cors(request: Request): Headers {
  const headers = new Headers({ Vary: "Origin", "Cache-Control": "no-store" });
  const origin = request.headers.get("Origin");
  const allowed = (env("PLATEWISE_ALLOWED_ORIGINS") ?? "").split(",").map((value) => value.trim());
  if (origin && allowed.includes(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Headers", "authorization, apikey, x-client-info, content-type");
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  }
  return headers;
}
export function response(request: Request, id: string, data: unknown, error?: unknown) {
  const headers = cors(request);
  headers.set("Content-Type", "application/json");
  headers.set("X-Request-ID", id);
  if (error !== undefined) {
    const e = error instanceof ApiError
      ? error
      : new ApiError("INTERNAL", "Something went wrong. Try again.", 500, true);
    if (!(error instanceof ApiError)) console.error("platewise_internal", id);
    return new Response(
      JSON.stringify({
        version: 1,
        ok: false,
        request_id: id,
        error: { code: e.code, message: e.message, retryable: e.retryable },
      }),
      { status: e.status, headers },
    );
  }
  return new Response(JSON.stringify({ version: 1, ok: true, request_id: id, data }), { headers });
}
