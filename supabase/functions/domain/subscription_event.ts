/** A subscription message, reduced to the few fields worth indexing. */
export type SubscriptionEvent = {
  subscriber: string | null;
  status: string | null;
  event_time: string | null;
  payload: Record<string, unknown>;
};

const firstText = (source: Record<string, unknown>, names: string[], max: number) => {
  for (const name of names) {
    const value = source[name];
    if (typeof value === "string" && value.trim().length > 0) return value.trim().slice(0, max);
  }
  return null;
};

/**
 * Reads a message from the subscription service. The format is not fixed in the
 * documentation we have, so any JSON object is accepted and kept whole. The
 * subscriber, status and time are picked out when they are present under the
 * names the service is known to use. Anything else, such as a list or a bare
 * value, is refused.
 */
export function parseSubscriptionEvent(json: unknown): SubscriptionEvent | null {
  if (typeof json !== "object" || json === null || Array.isArray(json)) return null;
  // The service puts the application's API key in every message. It is checked
  // by `notificationPassword` and must never be stored.
  const { password: _password, ...payload } = json as Record<string, unknown>;
  return {
    subscriber: firstText(payload, ["subscriberId", "subscriber_id", "msisdn", "address"], 64),
    status: firstText(payload, ["status", "subscriptionStatus", "subscription_status"], 40),
    event_time: firstText(payload, ["timeStamp", "timestamp", "time"], 40),
    payload,
  };
}

/** The API key the service put in a message, or null when there is none. */
export function notificationPassword(json: unknown): string | null {
  if (typeof json !== "object" || json === null || Array.isArray(json)) return null;
  const value = (json as Record<string, unknown>).password;
  return typeof value === "string" ? value : null;
}

/** Compares two secrets in time that does not depend on where they differ. */
export function secretsMatch(provided: string | null | undefined, expected: string | null | undefined) {
  if (!provided || !expected) return false;
  const a = new TextEncoder().encode(provided);
  const b = new TextEncoder().encode(expected);
  let difference = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) difference |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return difference === 0;
}
