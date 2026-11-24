import { ApiError, fail } from "../domain/contracts.ts";
import { env } from "./config.ts";

/** Reads a request body, refusing anything larger than [limit] bytes. */
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

/** Response headers. Only the configured web origins may call from a browser. */
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

/** The API v1 envelope. Unexpected errors are logged by request ID and never described. */
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
