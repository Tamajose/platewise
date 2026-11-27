import assert from "node:assert/strict";
import { ApiError } from "../domain/contracts.ts";
import { createPhoneProvider, createSubscriptionProvider } from "./applink.ts";

const environment = (values: Record<string, string | undefined>) => (name: string) => values[name];

/** A network that records the request and answers with the given body. */
function recorder(reply: unknown, status = 200) {
  const calls: { url: string; headers: Headers; body: Record<string, unknown> }[] = [];
  const network: typeof fetch = (input, init) => {
    calls.push({
      url: String(input),
      headers: new Headers(init?.headers),
      body: JSON.parse(init?.body as string),
    });
    return Promise.resolve(Response.json(reply, { status }));
  };
  return { calls, network };
}

const config = {
  APPLINK_APP_ID: "APP_000001",
  APPLINK_PASSWORD: "local-test-value",
};

Deno.test("an OTP request carries the tel: address to Applink", async () => {
  const { calls, network } = recorder({ statusCode: "S1000", referenceNo: "ref-1" });
  const phone = createPhoneProvider(environment(config), network);
  assert.equal(phone.available(), true);
  assert.deepEqual(await phone.requestOtp("+880 1416-177301"), { referenceNo: "ref-1" });
  const [call] = calls;
  assert.equal(call.url, "https://api.applink.com.bd/otp/request");
  assert.equal(call.headers.get("Content-Type"), "application/json;charset=utf-8");
  assert.equal(call.headers.get("X-Relay-Token"), null);
  assert.deepEqual(call.body, {
    applicationId: "APP_000001",
    password: "local-test-value",
    subscriberId: "tel:8801416177301",
  });
});

Deno.test("the relay token travels as X-Relay-Token when a relay is configured", async () => {
  const { calls, network } = recorder({ statusCode: "S1000", referenceNo: "ref-1" });
  const phone = createPhoneProvider(
    environment({
      ...config,
      APPLINK_BASE_URL: "https://relay.example/",
      APPLINK_RELAY_TOKEN: "secret",
    }),
    network,
  );
  await phone.requestOtp("tel:8801416177301");
  assert.equal(calls[0].url, "https://relay.example/otp/request");
  assert.equal(calls[0].headers.get("X-Relay-Token"), "secret");
});

Deno.test("HTTP 200 with a failure statusCode is treated as a failure", async () => {
  const { network } = recorder({ statusCode: "E1850", statusDetail: "Invalid OTP." });
  const phone = createPhoneProvider(environment(config), network);
  await assert.rejects(
    () => phone.verifyOtp("ref-1", "123456"),
    (error: unknown) =>
      error instanceof ApiError &&
      error.code === "E1850" &&
      error.status === 400 &&
      error.retryable === false &&
      error.message === "Invalid OTP.",
  );
});

Deno.test("configuration errors are 503 and rate limits are retryable 429", async () => {
  const blocked = createPhoneProvider(environment(config), recorder({ statusCode: "E1303" }).network);
  await assert.rejects(
    () => blocked.requestOtp("tel:8801416177301"),
    (error: unknown) => error instanceof ApiError && error.status === 503 && error.retryable === false,
  );
  const busy = createPhoneProvider(environment(config), recorder({ statusCode: "E1318" }).network);
  await assert.rejects(
    () => busy.requestOtp("tel:8801416177301"),
    (error: unknown) => error instanceof ApiError && error.status === 429 && error.retryable === true,
  );
});

Deno.test("a verified OTP returns the subscriber identity", async () => {
  const { network } = recorder({
    statusCode: "S1000",
    subscriberId: "tel:880*******301",
    subscriptionStatus: "REGISTERED",
  });
  const phone = createPhoneProvider(environment(config), network);
  assert.deepEqual(await phone.verifyOtp("ref-1", "123456"), {
    subscriberId: "tel:880*******301",
    subscriptionStatus: "REGISTERED",
  });
});

Deno.test("an unconfigured provider refuses locally", async () => {
  const phone = createPhoneProvider(environment({}), recorder({}).network);
  assert.equal(phone.available(), false);
  await assert.rejects(
    () => phone.requestOtp("tel:8801416177301"),
    (error: unknown) =>
      error instanceof ApiError && error.code === "PHONE_UNAVAILABLE" && error.status === 503,
  );
});

Deno.test("unregister posts action 0 to the subscription endpoint", async () => {
  const { calls, network } = recorder({ statusCode: "S1000", subscriptionStatus: "UNREGISTERED." });
  const subscriptions = createSubscriptionProvider(environment(config), network);
  assert.equal(subscriptions.available(), true);
  assert.deepEqual(await subscriptions.unregister("+880 1416-177301"), {
    subscriptionStatus: "UNREGISTERED.",
  });
  assert.equal(calls[0].url, "https://api.applink.com.bd/subscription/send");
  assert.deepEqual(calls[0].body, {
    applicationId: "APP_000001",
    password: "local-test-value",
    subscriberId: "tel:8801416177301",
    action: "0",
  });
});

Deno.test("an unconfigured subscription provider refuses locally", async () => {
  const subscriptions = createSubscriptionProvider(environment({}), recorder({}).network);
  assert.equal(subscriptions.available(), false);
  await assert.rejects(
    () => subscriptions.unregister("tel:8801416177301"),
    (error: unknown) =>
      error instanceof ApiError && error.code === "SUBSCRIPTION_UNAVAILABLE" && error.status === 503,
  );
});
