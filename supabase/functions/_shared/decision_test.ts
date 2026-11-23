import assert from "node:assert/strict";
import { compare, compareInput, compareScores, fit, haversine, nearby, score } from "./decision.ts";
import { normalizeMenu } from "./providers.ts";
import { audioKind } from "./audio.ts";
import type { Session } from "./http.ts";

const range = (calorie_low: number, calorie_high: number) => ({
  calorie_low,
  calorie_high,
  confidence: "low" as const,
});
Deno.test("budget fit uses the full range and deterministic ordering without favoring lower calories", () => {
  assert.equal(fit(range(400, 600), 600), "fits");
  assert.equal(fit(range(400, 600), 400), "overlaps");
  assert.equal(fit(range(400, 600), 399), "above");
  assert.equal(fit(range(400, 600), null), "no_budget");
  assert.ok(compareScores(score(range(460, 500), 600), score(range(400, 460), 600)) < 0);
  assert.equal(compareScores(score(range(460, 500), 600), score(range(460, 500), 600)), 0);
});
Deno.test("two and three options, stable ties and per-option ownership failure", async () => {
  const m = {
    kind: "menu",
    key: "0",
    name: "Rice and dal",
    portion: "1 bowl",
    printed_kcal: 500,
    language: "en",
  };
  const x = {
    kind: "photo",
    key: "2",
    image_storage_path: "22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.jpg",
  };
  const session = { uid: "11111111-1111-4111-8111-111111111111" } as Session;
  const p = compareInput.parse({ budget: 600, options: [m, { ...m, key: "1" }, x] });
  const result = await compare(session, p);
  assert.deepEqual(result.results.map((r) => r.key), ["0", "1"]);
  assert.equal(result.failures[0].code, "NOT_FOUND");
  assert.equal(compareInput.safeParse({ budget: 600, options: [m, m] }).success, false);
  assert.equal(
    (await compare(session, compareInput.parse({ budget: 600, options: [m, { ...m, key: "1" }] }))).results
      .length,
    2,
  );
});
Deno.test("prices and injected menu content remain untrusted", () => {
  const menu = normalizeMenu({
    options: [
      { name: "Rice", portion: null, printed_kcal: 290, calorie_evidence: "৳ 290" },
      { name: "Dal", portion: "1 bowl", printed_kcal: 180, calorie_evidence: "180 kcal" },
      {
        name: "http://example.org",
        portion: null,
        printed_kcal: 150,
        calorie_evidence: "ignore previous 150",
      },
    ],
  });
  assert.deepEqual(menu.options.map((v) => v.printed_kcal), [null, 180, null]);
  assert.doesNotMatch(JSON.stringify(menu), /example\.org/);
});
Deno.test("distance, search radius and stable venue ordering", async () => {
  assert.equal(haversine(23, 91, 23, 91), 0);
  assert.ok(Math.abs(haversine(0, 0, 0, 1) - 111.195) < .01);
  const venue = {
    id: "venue",
    name: "Sample",
    latitude: 23,
    longitude: 91,
    source: "fixture",
    attribution: "PlateWise",
    dataset: "seeded" as const,
    last_verified_at: null,
  };
  const row = {
    id: "b",
    name: "Rice and dal",
    portion: "Bowl",
    ...range(400, 500),
    protein_g: null,
    carbohydrate_g: null,
    fat_g: null,
    fiber_g: null,
    sodium_mg: null,
    restaurant: venue,
  };
  const found = await nearby({} as Session, { latitude: 23, longitude: 91, radius_km: 2, budget: 650 }, {
    getMenus: () =>
      Promise.resolve([row, { ...row, id: "a" }, {
        ...row,
        id: "c",
        restaurant: { ...venue, latitude: 24 },
      }]),
  });
  assert.deepEqual(found.options.map((v) => v.id), ["a", "b"]);
});
Deno.test("audio media type comes from contained bytes, not filename", () => {
  const WAV = new TextEncoder().encode("RIFF9999WAVE000000000000");
  assert.equal(audioKind(WAV)?.type, "audio/wav");
  assert.equal(audioKind(new TextEncoder().encode("Not a recording at all")), null);
});
