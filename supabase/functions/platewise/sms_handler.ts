import { ApiError } from "../domain/contracts.ts";
import { isOptOut, parseSmsMessage } from "../domain/sms_message.ts";
import { secretsMatch } from "../domain/subscription_event.ts";
import { readLimited } from "../infra/web.ts";

/** What the inbound SMS handler needs from outside, so tests can supply it. */
export type SmsServices = {
  /** The secret the callback address must carry. Unset means the endpoint is switched off. */
  token: () => string | undefined;
  /** The application id the message must carry, when configured. */
  appId?: () => string | undefined;
  /** Opts a subscriber out. Runs after the acknowledgement, never before it. */
  unregister?: (subscriberId: string) => Promise<{ subscriptionStatus: string }>;
  /** Runs work after the response. Defaults to EdgeRuntime.waitUntil when present. */
  schedule?: (work: Promise<unknown>) => void;
};

const limit = 16 * 1024;

const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

/** Applink expects this exact acknowledgement for every MO message. */
const acknowledged = () => reply(200, { statusCode: "S1000", statusDetail: "Success" });

/** Continues work after the response on a host that supports it. */
function background(work: Promise<unknown>) {
  const runtime = (globalThis as { EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void } })
    .EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(work);
}

/**
 * Receives inbound MO SMS from Applink. The address must carry the shared secret
 * as `?token=`. The body is acknowledged immediately and never logged, because an
 * MO message is private communication.
 *
 * A STOP, UNSUB or OFF message opts the subscriber out through the subscription
 * service after the acknowledgement. Nothing else in a message is acted on.
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
      const message = parseSmsMessage(json);
      if (!message) return acknowledged();
      const expectedApp = services.appId?.();
      if (expectedApp && message.applicationId !== expectedApp) return acknowledged();
      if (isOptOut(message.message) && services.unregister) {
        const work = services.unregister(message.sourceAddress).then(
          (result) => {
            const status = result.subscriptionStatus.trim().replace(/\.+$/, "").toUpperCase();
            console.info("sms_opt_out", id, status);
          },
          (error) => {
            console.error("sms_opt_out_failed", id, error instanceof ApiError ? error.code : "unknown");
          },
        );
        (services.schedule ?? background)(work);
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
