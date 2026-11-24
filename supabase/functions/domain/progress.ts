import { z } from "zod";
import { dayKey, fail, nutrientKeys, targetPolicy, uuid } from "./contracts.ts";

type Saved = {
  consumed_at: string;
  calorie_low: number;
  calorie_high: number;
  representative_calories: number;
  items: Partial<Record<typeof nutrientKeys[number], number | null>>[];
};
export type Overview = {
  local_day: string;
  profile: { timezone: string; height_cm: number; weight_kg: number } | null;
  meals: Saved[];
  water: { logged_at: string; amount_ml: number }[];
  targets: { effective_on: string; target_kcal: number | null }[];
};
function offsetDate(day: string, offset: number) {
  const start = new Date(day + "T00:00:00Z");
  start.setUTCDate(start.getUTCDate() + offset);
  return start.toISOString().slice(0, 10);
}
export function weekly(overview: Overview) {
  const zone = overview.profile?.timezone ?? "UTC";
  const days = Array.from({ length: 7 }, (_, i) => {
    const day = offsetDate(overview.local_day, i - 6);
    const target = overview.targets.filter((t) => t.effective_on <= day).at(-1)?.target_kcal ?? null;
    const meals = overview.meals.filter((m) => dayKey(new Date(m.consumed_at), zone) === day);
    const water = overview.water.filter((entry) => dayKey(new Date(entry.logged_at), zone) === day).reduce(
      (sum, entry) => sum + entry.amount_ml,
      0,
    );
    if (meals.length === 0) {
      return { day, target, low: null, high: null, representative: null, relation: null, water };
    }
    const low = meals.reduce((sum, m) => sum + m.calorie_low, 0);
    const high = meals.reduce((sum, m) => sum + m.calorie_high, 0);
    const representative = meals.reduce((sum, m) => sum + m.representative_calories, 0);
    return {
      day,
      target,
      low,
      high,
      representative,
      relation: target === null ? null : high < target ? "below" : low > target ? "above" : "overlaps",
      water,
    };
  });
  const logged = days.filter((x) => x.representative !== null);
  const paired = logged.filter((x) => x.target !== null);
  const items = overview.meals.flatMap((m) => m.items);
  const intakeMean = logged.length
    ? Math.round(logged.reduce((n, d) => n + d.representative!, 0) / logged.length)
    : null;
  const targetMean = paired.length
    ? Math.round(paired.reduce((n, d) => n + d.target!, 0) / paired.length)
    : null;
  return {
    days,
    logged_days: logged.length,
    days_with_logged_target: paired.length,
    overlapping_days: paired.filter((x) => x.relation === "overlaps").length,
    representative_mean: intakeMean,
    target_mean: targetMean,
    water_logged_days: days.filter((d) => d.water > 0).length,
    nutrients: Object.fromEntries(nutrientKeys.map((key) => {
      const known = items.map((i) => i[key]).filter((v): v is number => typeof v === "number");
      return [key, {
        total: known.length ? Math.round(10 * known.reduce((a, b) => a + b, 0)) / 10 : null,
        known_items: known.length,
        total_items: items.length,
      }];
    })),
  };
}
export function summaryFacts(aggregate: ReturnType<typeof weekly>) {
  if (aggregate.logged_days < 2) return [];
  const facts = [
    "You logged meals on " + aggregate.logged_days + " of 7 days.",
    "Logged intake averaged about " + aggregate.representative_mean + " kcal on those days.",
  ];
  if (aggregate.days_with_logged_target > 0) {
    facts.push(
      "The recorded calorie range overlapped the target on " + aggregate.overlapping_days + " of " +
        aggregate.days_with_logged_target + " logged days with a target.",
    );
  }
  if (aggregate.water_logged_days > 0) {
    facts.push("You logged water on " + aggregate.water_logged_days + " of 7 days.");
  }
  return facts;
}
export const energyInput = z.strictObject({
  age: z.number().int().min(19).max(78),
  coefficient: z.enum(["plus_5", "minus_161"]),
  activity: z.enum(["low", "some", "regular"]),
  eligible: z.literal(true),
});
export function energy(overview: Overview, input: z.infer<typeof energyInput>) {
  const p = overview.profile;
  if (!p) return fail("PROFILE_REQUIRED", "Set up your height and weight before estimating energy needs.");
  const resting = 10 * p.weight_kg + 6.25 * p.height_cm - 5 * input.age +
    (input.coefficient === "plus_5" ? 5 : -161);
  const factor = { low: 1.2, some: 1.4, regular: 1.6 }[input.activity];
  const total = Math.round(resting * factor);
  return {
    resting_kcal: Math.round(resting),
    total_kcal: total,
    activity_factor: factor,
    can_apply: total >= targetPolicy.minimum && total <= targetPolicy.maximum,
  };
}
export const waterInput = z.strictObject({ id: uuid, amount_ml: z.number().int().min(1).max(2000) });
export const editWaterInput = waterInput.extend({ expected_updated_at: z.iso.datetime({ offset: true }) });
export const correctionInput = z.strictObject({
  id: uuid,
  food_key: z.enum(["rice", "dal", "egg", "chana", "roti", "khichuri"]),
  grams: z.number().int().min(1).max(3000),
  calorie_low: z.number().int().min(0).max(6000),
  calorie_high: z.number().int().min(0).max(6000),
}).refine((x) => x.calorie_high >= x.calorie_low);
