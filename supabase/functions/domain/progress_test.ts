import assert from "node:assert/strict";
import { energy, energyInput, type Overview, summaryFacts, weekly } from "./progress.ts";

const fixture: Overview = {
  local_day: "2026-11-22",
  profile: { timezone: "Asia/Dhaka", height_cm: 170, weight_kg: 70 },
  targets: [{ effective_on: "2026-11-15", target_kcal: 1800 }, {
    effective_on: "2026-11-22",
    target_kcal: 2200,
  }],
  meals: [
    {
      consumed_at: "2026-11-21T17:59:00Z",
      calorie_low: 1700,
      calorie_high: 1850,
      representative_calories: 1775,
      items: [{ protein_g: 10 }],
    },
    {
      consumed_at: "2026-11-21T18:01:00Z",
      calorie_low: 510,
      calorie_high: 640,
      representative_calories: 575,
      items: [{ protein_g: null }],
    },
  ],
  water: [{ logged_at: "2026-11-22T00:00:00Z", amount_ml: 250 }],
};
Deno.test("week boundaries preserve absence, historical targets, calorie range relation and nutrient nulls", () => {
  const week = weekly(fixture);
  assert.equal(week.days[0].day, "2026-11-16");
  assert.equal(week.days[0].representative, null);
  assert.equal(week.days[5].target, 1800);
  assert.equal(week.days[5].relation, "overlaps");
  assert.equal(week.days[6].target, 2200);
  assert.equal(week.days[6].water, 250);
  assert.equal(week.overlapping_days, 1);
  assert.deepEqual(week.nutrients.protein_g, { total: 10, known_items: 1, total_items: 2 });
  assert.deepEqual(week.nutrients.sodium_mg, { total: null, known_items: 0, total_items: 2 });
  const facts = summaryFacts(week);
  assert.match(facts.join(" "), /2 of 7 days/);
  assert.match(facts.join(" "), /1175 kcal/);
  assert.deepEqual(summaryFacts(weekly({ ...fixture, meals: [] })), []);
});
Deno.test("Mifflin–St Jeor uses resting energy and a separate activity factor", () => {
  const p = energyInput.parse({ age: 30, coefficient: "plus_5", activity: "some", eligible: true });
  assert.deepEqual(energy(fixture, p), {
    resting_kcal: 1618,
    total_kcal: 2265,
    activity_factor: 1.4,
    can_apply: true,
  });
  assert.equal(energyInput.safeParse({ ...p, age: 18 }).success, false);
  assert.equal(energyInput.safeParse({ ...p, eligible: false }).success, false);
});
