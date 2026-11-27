import {
  notificationPassword,
  parseSubscriptionEvent,
  secretsMatch,
  type SubscriptionEvent,
} from "../domain/subscription_event.ts";
import { readLimited } from "../infra/web.ts";
import { ApiError } from "../domain/contracts.ts";

/** What the handler needs from outside, so tests can supply it. */
export type NotifyServices = {
  /** The secret the address must carry. Unset means the endpoint is switched off. */
  secret: () => string | undefined;
  save: (event: SubscriptionEvent) => Promise<void>;
  /** The application's API key. When set, a message must carry the same key in its body. */
  applinkPassword?: () => string | undefined;
};

const limit = 16 * 1024;

const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

/**
 * Receives messages from Banglalink's subscription service. The address must
 * carry the shared secret as `?token=`, because the messages are not signed.
 * Nothing about a message is logged beyond a request ID, since it holds a
 * phone number.
 */
export function createNotifyHandler(services: NotifyServices) {
  return async (request: Request) => {
    const id = crypto.randomUUID();
    try {
      if (request.method !== "POST") return reply(405, { statusCode: "E1000", statusDetail: "Use POST." });
      const expected = services.secret();
      if (!expected) return reply(503, { statusCode: "E1000", statusDetail: "Not available." });
      if (!secretsMatch(new URL(request.url).searchParams.get("token"), expected)) {
        return reply(401, { statusCode: "E1313", statusDetail: "Not authorised." });
      }
      let json: unknown;
      try {
        json = JSON.parse(new TextDecoder().decode(await readLimited(request, limit)));
      } catch (error) {
        if (error instanceof ApiError) {
          return reply(error.status, { statusCode: "E1000", statusDetail: "Too large." });
        }
        return reply(400, { statusCode: "E1000", statusDetail: "Send a JSON object." });
      }
      const key = services.applinkPassword?.();
      if (key && !secretsMatch(notificationPassword(json), key)) {
        return reply(401, { statusCode: "E1313", statusDetail: "Not authorised." });
      }
      const event = parseSubscriptionEvent(json);
      if (!event) return reply(400, { statusCode: "E1000", statusDetail: "Send a JSON object." });
      await services.save(event);
      return reply(200, { statusCode: "S1000", statusDetail: "Success" });
    } catch (error) {
      const reason = error instanceof ApiError
        ? error.code
        : error instanceof Error
        ? error.message
        : "unknown";
      console.error("subscription_notify_internal", id, reason);
      return reply(500, { statusCode: "E1000", statusDetail: "Try again." });
    }
  };
}
