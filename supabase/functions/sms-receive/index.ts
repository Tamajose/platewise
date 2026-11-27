import { env } from "../infra/config.ts";
import { createSmsHandler } from "../platewise/sms_handler.ts";

Deno.serve(createSmsHandler({
  token: () => env("SMS_RECEIVE_TOKEN"),
  appId: () => env("APPLINK_APP_ID"),
}));
