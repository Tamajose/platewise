import { ApiError } from "../domain/contracts.ts";
import { secretsMatch } from "../domain/subscription_event.ts";
import { readLimited } from "../infra/web.ts";

/** What the inbound SMS handler needs from outside, so tests can supply it. */
export type SmsServices = {
  /** The secret the callback address must carry. Unset means the endpoint is switched off. */
  token: () => string | undefined;
  /** The application id the message must carry, when configured. */
  appId?: () => string | undefined;
};

const limit = 16 * 1024;

const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

/** Applink expects this exact acknowledgement for every MO message. */
const acknowledged = () => reply(200, { statusCode: "S1000", statusDetail: "Success" });

/**
 * Receives inbound MO SMS from Applink. The address must carry the shared secret
 * as `?token=`. The body is acknowledged immediately and never logged, because an
 * MO message is private communication.
 *
 * MO processing (STOP / UNSUB / OFF) is not wired yet: this acknowledges and
 * discards, which satisfies provisioning without acting on a single SMS.
 */
export function createSmsHandler(services: SmsServices) {
  return async (request: Request) => {
    const id = crypto.randomUUID();
    try {
      if (request.method !== "POST") {
        return reply(405, { statusCode: "E1000", statusDetail: "Use POST." });
      }
      const expected = services.token();
      if (!expected) return reply(503, { statusCode: "E1000", statusDetail: "Not available." });
      if (!secretsMatch(new URL(request.url).searchParams.get("token"), expected)) {
        return reply(401, { statusCode: "E1313", statusDetail: "Not authorised." });
      }
      let json: unknown;
      try {
        json = JSON.parse(new TextDecoder().decode(await readLimited(request, limit)));
      } catch {
        return acknowledged();
      }
      const expectedApp = services.appId?.();
      const appId = typeof json === "object" && json !== null
        ? (json as { applicationId?: unknown }).applicationId
        : undefined;
      if (expectedApp && typeof appId === "string" && appId !== expectedApp) {
        return acknowledged();
      }
      return acknowledged();
    } catch (error) {
      const reason = error instanceof ApiError
        ? error.code
        : error instanceof Error
        ? error.message
        : "unknown";
      console.error("sms_receive_internal", id, reason);
      return acknowledged();
    }
  };
}
