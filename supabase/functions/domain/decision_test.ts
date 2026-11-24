import assert from "node:assert/strict";
import { compareScores, fit, haversine, rankNearby, score } from "./decision.ts";
import { audioKind } from "./media.ts";
import { normalizeMenu } from "./menu.ts";

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
Deno.test("a menu with no readable names is rejected", () => {
  assert.throws(
    () =>
      normalizeMenu({
        options: [{ name: "  ", portion: null, printed_kcal: null, calorie_evidence: null }],
      }),
    /No meal names/,
  );
});
Deno.test("distance, search radius and stable venue ordering", () => {
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
  const found = rankNearby(
    [row, { ...row, id: "a" }, { ...row, id: "c", restaurant: { ...venue, latitude: 24 } }],
    { latitude: 23, longitude: 91, radius_km: 2, budget: 650 },
  );
  assert.deepEqual(found.options.map((v) => v.id), ["a", "b"]);
  assert.equal(found.dataset, "seeded");
});
Deno.test("audio media type comes from contained bytes, not filename", () => {
  const WAV = new TextEncoder().encode("RIFF9999WAVE000000000000");
  assert.equal(audioKind(WAV)?.type, "audio/wav");
  assert.equal(audioKind(new TextEncoder().encode("Not a recording at all")), null);
});
