import assert from "node:assert/strict";
import {
  parseSubscriptionEvent,
  secretsMatch,
  type SubscriptionEvent,
} from "../domain/subscription_event.ts";
import { createNotifyHandler } from "./notify_handler.ts";

const secret = "s3cret-value";

function setup(configured: string | null = secret, applinkPassword?: string) {
  const saved: SubscriptionEvent[] = [];
  const handler = createNotifyHandler({
    secret: () => configured ?? undefined,
    applinkPassword: () => applinkPassword,
    save: (event) => {
      saved.push(event);
      return Promise.resolve();
    },
  });
  const post = (body: BodyInit | null, token: string | null = secret, method = "POST") =>
    handler(
      new Request(
        "https://example.test/functions/v1/subscription-notify" + (token === null ? "" : "?token=" + token),
        {
          method,
          body: method === "POST" ? body : null,
          headers: { "Content-Type": "application/json" },
        },
      ),
    );
  return { saved, post };
}

Deno.test("a message with the right secret is stored and acknowledged", async () => {
  const { saved, post } = setup();
  const result = await post(
    JSON.stringify({
      subscriberId: "tel:8801700000000",
      status: "REGISTERED",
      timeStamp: "2026-11-27 10:00:00",
      extra: 1,
    }),
  );
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), { statusCode: "S1000", statusDetail: "Success" });
  assert.equal(saved.length, 1);
  assert.equal(saved[0].subscriber, "tel:8801700000000");
  assert.equal(saved[0].status, "REGISTERED");
  assert.equal(saved[0].event_time, "2026-11-27 10:00:00");
  assert.equal(saved[0].payload.extra, 1);
});

Deno.test("a wrong, missing or empty secret is refused and nothing is stored", async () => {
  const { saved, post } = setup();
  for (const token of ["wrong", null, ""]) {
    assert.equal((await post("{}", token)).status, 401, String(token));
  }
  assert.equal(saved.length, 0);
});

Deno.test("the endpoint is off until a secret is configured", async () => {
  const { saved, post } = setup(null);
  assert.equal((await post("{}")).status, 503);
  const { post: emptyPost } = setup("");
  assert.equal((await emptyPost("{}", "")).status, 503);
  assert.equal(saved.length, 0);
});

Deno.test("only POST with a JSON object of reasonable size is accepted", async () => {
  const { saved, post } = setup();
  assert.equal((await post(null, secret, "GET")).status, 405);
  assert.equal((await post("not json")).status, 400);
  assert.equal((await post("[1,2]")).status, 400);
  assert.equal((await post("7")).status, 400);
  assert.equal((await post(JSON.stringify({ blob: "x".repeat(20 * 1024) }))).status, 413);
  assert.equal(saved.length, 0);
});

Deno.test("a failure to store is reported without details", async () => {
  const handler = createNotifyHandler({
    secret: () => secret,
    save: () => Promise.reject(new Error("tel:8801700000000 broke the database")),
  });
  const result = await handler(
    new Request("https://example.test/x?token=" + secret, { method: "POST", body: "{}" }),
  );
  assert.equal(result.status, 500);
  assert.doesNotMatch(await result.text(), /8801700000000|database/);
});

Deno.test("fields are trimmed, limited and read under the known names", () => {
  const event = parseSubscriptionEvent({
    msisdn: "  tel:1  ",
    subscriptionStatus: "x".repeat(100),
    timestamp: 5,
  });
  assert.equal(event?.subscriber, "tel:1");
  assert.equal(event?.status?.length, 40);
  assert.equal(event?.event_time, null);
  assert.equal(parseSubscriptionEvent(null), null);
});

Deno.test("secrets compare equal only when identical", () => {
  assert.equal(secretsMatch("abc", "abc"), true);
  assert.equal(secretsMatch("abc", "abd"), false);
  assert.equal(secretsMatch("abc", "abcd"), false);
  assert.equal(secretsMatch("", ""), false);
  assert.equal(secretsMatch(null, "abc"), false);
});

Deno.test("the API key in a message is checked when one is configured and never stored", async () => {
  const { saved, post } = setup(secret, "the-api-key");
  const body = (password?: string) =>
    JSON.stringify({ subscriberId: "tel:8801700000000", status: "REGISTERED", password });
  assert.equal((await post(body("wrong"))).status, 401);
  assert.equal((await post(body())).status, 401);
  assert.equal(saved.length, 0);
  assert.equal((await post(body("the-api-key"))).status, 200);
  assert.equal(saved.length, 1);
  assert.equal("password" in saved[0].payload, false);
  assert.doesNotMatch(JSON.stringify(saved[0]), /the-api-key/);
});

Deno.test("without a configured key the message is still stored without its password", async () => {
  const { saved, post } = setup();
  assert.equal((await post(JSON.stringify({ status: "X", password: "leaked" }))).status, 200);
  assert.doesNotMatch(JSON.stringify(saved[0]), /leaked/);
});
