import { env } from "../infra/config.ts";
import { saveSubscriptionEvent } from "../infra/subscription_events.ts";
import { adminClient } from "../infra/supabase.ts";
import { createNotifyHandler } from "../platewise/notify_handler.ts";

Deno.serve(createNotifyHandler({
  secret: () => env("SUBSCRIPTION_NOTIFY_TOKEN"),
  applinkPassword: () => env("APPLINK_PASSWORD"),
  save: (event) => saveSubscriptionEvent(adminClient(), event),
}));
