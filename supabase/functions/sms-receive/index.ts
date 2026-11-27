import { env } from "../infra/config.ts";
import { createSmsHandler } from "../platewise/sms_handler.ts";
import { createSubscriptionProvider } from "../providers/applink.ts";

const subscriptions = createSubscriptionProvider(env);

Deno.serve(createSmsHandler({
  token: () => env("SMS_RECEIVE_TOKEN"),
  appId: () => env("APPLINK_APP_ID"),
  unregister: (subscriberId) => subscriptions.unregister(subscriberId),
}));
