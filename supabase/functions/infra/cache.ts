import { fail } from "../domain/contracts.ts";
import type { AiProviders, Capability } from "../domain/ports.ts";
import { dataError, rpc, type Session } from "./supabase.ts";

/**
 * Claims one unit of the person's daily AI allowance. Fails when the AI
 * service for [capability] is not configured or the allowance is spent.
 */
export async function reserve(session: Session, ai: AiProviders, capability: Capability) {
  if (!ai.available(capability)) {
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

/**
 * Returns a stored result for the same input, provider and model, or runs
 * [work] once, within the allowance, and stores what it returns.
 */
export async function cached<T>(
  session: Session,
  ai: AiProviders,
  capability: Capability,
  action: string,
  seed: Uint8Array | string,
  work: () => Promise<T>,
) {
  const startedAt = new Date().toISOString();
  const key = await sha(
    JSON.stringify([1, action, ai.identity.kind, ai.identity.vision, ai.identity.text, await sha(seed)]),
  );
  const { data, error } = await session.admin.from("ai_cache").select("data")
    .eq("user_id", session.uid).eq("cache_key", key).gt("expires_at", new Date().toISOString()).maybeSingle();
  if (error) dataError(error);
  if (data) return data.data as T;
  await reserve(session, ai, capability);
  const result = await work();
  await rpc(session.admin, "pw_store_ai", {
    p_user: session.uid,
    p_key: key,
    p_data: result,
    p_started_at: startedAt,
  });
  return result;
}
