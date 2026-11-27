import { ApiError } from "../domain/contracts.ts";
import type { PhoneProvider, SubscriptionProvider } from "../domain/ports.ts";

type Get = (name: string) => string | undefined;

/** Applink answers failures with HTTP 200 and a statusCode, so the body decides. */
const timeoutMs = 15_000;
const defaultBaseUrl = "https://api.applink.com.bd";

type Config = {
  appId: string;
  password: string;
  baseUrl: string;
  relayToken?: string;
};

type Reply = Record<string, unknown> & { statusCode?: unknown; statusDetail?: unknown };

function readConfig(get: Get): Config | null {
  const appId = get("APPLINK_APP_ID")?.trim();
  const password = get("APPLINK_PASSWORD")?.trim();
  if (!appId || !password) return null;
  const baseUrl = (get("APPLINK_BASE_URL")?.trim() || defaultBaseUrl).replace(/\/+$/, "");
  const relayToken = get("APPLINK_RELAY_TOKEN")?.trim() || undefined;
  return { appId, password, baseUrl, relayToken };
}

/** Configuration codes mean the integration is down; rate limits are transient. */
function statusFor(code: string): number {
  if (code === "E1318" || code === "E1319") return 429;
  if (code === "E1303" || code === "E1309" || code === "E1313") return 503;
  return 400;
}

const transient = (code: string) => code === "E1318" || code === "E1319";

/** One place turns a number into the tel: address Applink expects. */
function subscriberAddress(value: string): string {
  const compact = value.trim().replace(/[\s()-]/g, "");
  if (!compact) throw new ApiError("INVALID_SUBSCRIBER", "Enter a mobile number.", 400);
  return compact.startsWith("tel:") ? compact : `tel:${compact.replace(/^\+/, "")}`;
}

const stringField = (reply: Reply, key: string) => typeof reply[key] === "string" ? reply[key] as string : "";

async function post(
  config: Config,
  path: string,
  body: Record<string, unknown>,
  network: typeof fetch,
  timeout: number,
): Promise<Reply> {
  const headers: Record<string, string> = { "Content-Type": "application/json;charset=utf-8" };
  if (config.relayToken) headers["X-Relay-Token"] = config.relayToken;
  let response: Response;
  try {
    response = await network(`${config.baseUrl}${path}`, {
      method: "POST",
      headers,
      body: JSON.stringify({ applicationId: config.appId, password: config.password, ...body }),
      signal: AbortSignal.timeout(timeout),
    });
  } catch {
    throw new ApiError("APPLINK_UNAVAILABLE", "Applink could not be reached. Try again.", 502, true);
  }
  let reply: Reply;
  try {
    reply = JSON.parse(await response.text()) as Reply;
  } catch {
    if (response.status === 403) {
      throw new ApiError(
        "APPLINK_UNAVAILABLE",
        "The Applink relay rejected the request. Check APPLINK_RELAY_TOKEN.",
        503,
      );
    }
    throw new ApiError("APPLINK_UNAVAILABLE", "Applink returned an unreadable reply.", 502, true);
  }
  const code = typeof reply.statusCode === "string" ? reply.statusCode : "";
  if (code !== "S1000") {
    const detail = stringField(reply, "statusDetail").slice(0, 200) ||
      "Applink request failed. Try again.";
    throw new ApiError(code || "APPLINK_UNAVAILABLE", detail, statusFor(code), transient(code));
  }
  return reply;
}

/**
 * Phone verification through Banglalink's Applink OTP service.
 *
 * Point `APPLINK_BASE_URL` at Applink directly, or at the static-IP relay; when
 * it is the relay, `APPLINK_RELAY_TOKEN` is sent as `X-Relay-Token`. Success is
 * `statusCode === "S1000"` even though failures also arrive with HTTP 200.
 */
export function createPhoneProvider(
  get: Get,
  network: typeof fetch = fetch,
  timeout = timeoutMs,
): PhoneProvider {
  const config = readConfig(get);
  const unavailable = () =>
    Promise.reject(
      new ApiError("PHONE_UNAVAILABLE", "Phone verification is unavailable here.", 503),
    );
  return {
    available: () => config !== null,
    async requestOtp(subscriberId) {
      if (!config) return unavailable();
      const reply = await post(
        config,
        "/otp/request",
        { subscriberId: subscriberAddress(subscriberId) },
        network,
        timeout,
      );
      const referenceNo = stringField(reply, "referenceNo");
      if (!referenceNo) {
        throw new ApiError("INVALID_RESPONSE", "Phone verification did not return a reference.", 502);
      }
      return { referenceNo };
    },
    async verifyOtp(referenceNo, otp) {
      if (!config) return unavailable();
      const reply = await post(config, "/otp/verify", { referenceNo, otp }, network, timeout);
      const subscriberId = stringField(reply, "subscriberId");
      if (!subscriberId) {
        throw new ApiError("INVALID_RESPONSE", "Phone verification did not return a subscriber.", 502);
      }
      return { subscriberId, subscriptionStatus: stringField(reply, "subscriptionStatus") };
    },
  };
}

/**
 * Subscription changes through Applink. Unregister posts action "0" to
 * `/subscription/send`; the desired state is UNREGISTERED whether or not the
 * subscriber was registered before, so a repeat is still success.
 */
export function createSubscriptionProvider(
  get: Get,
  network: typeof fetch = fetch,
  timeout = timeoutMs,
): SubscriptionProvider {
  const config = readConfig(get);
  const unavailable = () =>
    Promise.reject(
      new ApiError("SUBSCRIPTION_UNAVAILABLE", "Subscription changes are unavailable here.", 503),
    );
  return {
    available: () => config !== null,
    async unregister(subscriberId) {
      if (!config) return unavailable();
      const reply = await post(
        config,
        "/subscription/send",
        { subscriberId: subscriberAddress(subscriberId), action: "0" },
        network,
        timeout,
      );
      return { subscriptionStatus: stringField(reply, "subscriptionStatus") };
    },
  };
}
