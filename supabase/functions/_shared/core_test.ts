import assert from "node:assert/strict";
import {
  actions,
  ApiError,
  dayKey,
  estimate,
  modelEstimate,
  ownedPath,
  redact,
  validateTarget,
} from "./contracts.ts";
import { OpenAIProvider, withRetry } from "./providers.ts";
import { stripImageMetadata } from "./http.ts";
import { handler } from "../platewise/handler.ts";

const profile = actions.update_profile.parse({
  height_cm: 170,
  weight_kg: 70,
  daily_calorie_target: 1200,
  timezone: "Asia/Dhaka",
  preferred_units: "metric",
  target_confirmed: true,
});
Deno.test("target boundaries, eligibility, timezone and future dates", () => {
  for (const allowed of [1200, 1201, 4999, 5000, null]) {
    validateTarget({ ...profile, daily_calorie_target: allowed });
  }
  for (const denied of [1199, 5001]) {
    assert.throws(() => validateTarget({ ...profile, daily_calorie_target: denied }), /pilot range/);
  }
  assert.throws(() => validateTarget({ ...profile, target_confirmed: false }), /Confirm/);
  assert.equal(dayKey(new Date("2026-11-21T18:30:00Z"), "Asia/Dhaka"), "2026-11-22");
  assert.equal(dayKey(new Date("2026-11-21T18:30:00Z"), "America/New_York"), "2026-11-21");
});

const food = {
  name: "Rice",
  quantity: 1,
  unit: "cup",
  estimated_grams: 160,
  calorie_low: 180,
  calorie_high: 241,
  protein_g: 4,
  carbohydrate_g: null,
  fat_g: null,
  fiber_g: null,
  sodium_mg: null,
};
const meal = { items: [food], confidence: "high", assumptions: ["Cooked rice"], question: null };
Deno.test("server computes range and midpoint and preserves unknown nutrients", () => {
  const result = estimate(modelEstimate.parse(meal), "test");
  assert.equal(result.representative_calories, 211);
  assert.equal(result.items[0].carbohydrate_g, null);
  assert.equal(result.confidence, "medium");
  assert.equal(modelEstimate.safeParse({ ...meal, items: [{ ...food, calorie_low: 300 }] }).success, false);
});
Deno.test("only the owner can reference a private path", () => {
  assert.throws(
    () =>
      ownedPath(
        "11111111-1111-4111-8111-111111111111/33333333-3333-4333-8333-333333333333.jpg",
        "22222222-2222-4222-8222-222222222222",
      ),
    /unavailable/,
  );
});
Deno.test("provider request does not expose the user's profile or contact details and validates structure", async () => {
  assert.equal(
    redact("Rice, person@example.org; https://example.org"),
    "Rice, [contact removed]; [link removed]",
  );
  const fake: typeof fetch = (_input, init) => {
    const body = JSON.parse(init?.body as string);
    assert.equal(body.store, false);
    assert.equal(body.response_format.json_schema.strict, true);
    assert.equal(body.tools, undefined);
    assert.match(body.messages[0].content, /untrusted/);
    assert.doesNotMatch(body.messages[1].content, /example.org/);
    return Promise.resolve(
      Response.json({ choices: [{ finish_reason: "stop", message: { content: JSON.stringify(meal) } }] }),
    );
  };
  const provider = new OpenAIProvider({
    kind: "openai",
    key: "local-test-value",
    vision: "fixture-model",
    text: "fixture-model",
    speech: "fixture-model",
  }, fake);
  assert.equal((await provider.analyzeText("Rice, person@example.org", "en")).calorie_high, 241);
});
Deno.test("retry once for transient errors only", async () => {
  let count = 0;
  await assert.rejects(
    withRetry(() => Promise.reject(new ApiError("RETRY", String(++count), 503, true)), 0),
    /2/,
  );
  await assert.rejects(withRetry(() => Promise.reject(new ApiError("INVALID", String(++count))), 0), /3/);
});
Deno.test("edge refuses missing session with a request ID", async () => {
  const response = await handler(new Request("https://backend.example/platewise", { method: "POST" }));
  assert.equal(response.status, 401);
  const data = await response.json();
  assert.equal(data.error.code, "SESSION_REQUIRED");
  assert.ok(data.request_id);
});

Deno.test("private image copies remove PNG text and WebP EXIF from provider payloads", () => {
  const encoder = new TextEncoder();
  const chunk = (name: string, data: number[], png: boolean) => {
    const bytes = new Uint8Array(data.length + (png ? 12 : 8 + (data.length % 2)));
    bytes.set(encoder.encode(name), png ? 4 : 0);
    new DataView(bytes.buffer).setUint32(png ? 0 : 4, data.length, !png);
    bytes.set(data, 8);
    return bytes;
  };
  const privateData = [...encoder.encode("private contact@example.org")];
  const png = Uint8Array.from([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk("tEXt", privateData, true),
    ...chunk("IDAT", [1], true),
    ...chunk("IEND", [], true),
  ]);
  const webp = Uint8Array.from([
    ...encoder.encode("RIFF0000WEBP"),
    ...chunk("EXIF", privateData, false),
    ...chunk("VP8 ", [1], false),
  ]);
  for (const [bytes, type] of [[png, "image/png"], [webp, "image/webp"]] as const) {
    const cleaned = stripImageMetadata(bytes, type);
    assert.ok(cleaned.length < bytes.length);
    assert.doesNotMatch(new TextDecoder().decode(cleaned), /example.org/);
  }
});
