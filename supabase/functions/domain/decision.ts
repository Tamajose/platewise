import { z } from "zod";
import { confidence, language, photoPath, redact } from "./contracts.ts";
import type { MealEstimate, MenuRow } from "./ports.ts";

const optionId = z.string().regex(/^[\w-]{1,40}$/);
const menuName = z.string().trim().min(1).max(100);
const option = z.discriminatedUnion("kind", [
  z.strictObject({ kind: z.literal("photo"), key: optionId, image_storage_path: photoPath }),
  z.strictObject({
    kind: z.literal("menu"),
    key: optionId,
    name: menuName,
    portion: z.string().trim().max(100).nullable(),
    printed_kcal: z.number().int().min(15).max(6000).nullable(),
    language,
  }),
]);
export const compareInput = z.strictObject({
  options: z.array(option).min(2).max(3),
  budget: z.number().int().min(1).max(5000).nullable(),
}).refine((p) => new Set(p.options.map((o) => o.key)).size === p.options.length, "Options need unique keys.");
export const nearbyInput = z.strictObject({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  radius_km: z.number().min(0.5).max(25),
  budget: z.number().int().min(1).max(5000).nullable(),
});

export type Fit = "fits" | "overlaps" | "above" | "no_budget";
type RankedEstimate = { calorie_low: number; calorie_high: number; confidence: z.infer<typeof confidence> };

/** Whether the whole range, part of it or none of it fits [budget]. */
export function fit(range: RankedEstimate, budget: number | null): Fit {
  if (budget === null) return "no_budget";
  if (range.calorie_high <= budget) return "fits";
  if (range.calorie_low <= budget) return "overlaps";
  return "above";
}
const order: Fit[] = ["fits", "overlaps", "above", "no_budget"];
const trust = ["high", "medium", "low"];

/** Sort key: fit first, then overage, then confidence, then relative range width. */
export function score(range: RankedEstimate, budget: number | null) {
  const width = range.calorie_high - range.calorie_low;
  const uncertainty = Math.round(1000 * width / Math.max(1, range.calorie_low + range.calorie_high));
  const overage = budget === null ? 0 : Math.max(0, range.calorie_low - budget);
  return [order.indexOf(fit(range, budget)), overage, trust.indexOf(range.confidence), uncertainty];
}
export function compareScores(a: number[], b: number[]) {
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return a[i] - b[i];
  return 0;
}
export function reasoning(range: RankedEstimate, budget: number | null) {
  switch (fit(range, budget)) {
    case "fits":
      return "The full estimated range fits this budget at the stated portion.";
    case "overlaps":
      return "The range crosses your budget. The actual portion can change the fit.";
    case "above":
      return "The lower end of the estimated range exceeds this budget at the stated portion.";
    case "no_budget":
      return "Set a meal budget to check fit. Visible differences are estimates.";
  }
}

/** An estimate for a dish whose calories the person reviewed from the menu. */
export function printedEstimate(name: string, portion: string | null, kcal: number): MealEstimate {
  return {
    items: [{
      name: redact(name).slice(0, 100) || "Menu dish",
      quantity: 1,
      unit: "serving",
      calorie_low: kcal,
      calorie_high: kcal,
      estimated_grams: null,
      normalized_food_reference: null,
      protein_g: null,
      carbohydrate_g: null,
      fat_g: null,
      fiber_g: null,
      sodium_mg: null,
      nutrient_source: "unavailable",
      provenance: "menu_text",
    }],
    confidence: "medium",
    assumptions: [
      "Uses the calorie value you reviewed from the menu. The actual serving may vary.",
      redact(portion || "One menu serving"),
    ],
    question: null,
    calorie_low: kcal,
    calorie_high: kcal,
    representative_calories: kcal,
    model: "reviewed-menu-text",
  };
}

export type Attempt = {
  key: string;
  index: number;
  estimate: MealEstimate | null;
  image_storage_path: string | null;
  error: { code: string; message: string; retryable: boolean } | null;
};

/** Ranks the options that were estimated and lists the ones that failed. */
export function rankAttempts(attempts: Attempt[], budget: number | null) {
  const sorted = attempts.filter((x) => x.estimate !== null).sort((a, b) =>
    compareScores(score(a.estimate!, budget), score(b.estimate!, budget)) || a.index - b.index
  );
  return {
    results: sorted.map((x, index) => ({
      key: x.key,
      estimate: x.estimate,
      image_storage_path: x.image_storage_path,
      rank: index + 1,
      fit: fit(x.estimate!, budget),
      reason: reasoning(x.estimate!, budget),
    })),
    failures: attempts.flatMap((x) => x.error ? [{ key: x.key, ...x.error }] : []),
  };
}

export function haversine(aLat: number, aLon: number, bLat: number, bLon: number) {
  const rad = Math.PI / 180;
  const value = Math.sin((bLat - aLat) * rad / 2) ** 2 +
    Math.cos(aLat * rad) * Math.cos(bLat * rad) * Math.sin((bLon - aLon) * rad / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(Math.min(1, value)));
}

/** Seeded venues within the radius, best fit first and then nearest. */
export function rankNearby(rows: MenuRow[], p: z.infer<typeof nearbyInput>) {
  const options = rows.map((row) => {
    const distance = haversine(p.latitude, p.longitude, row.restaurant.latitude, row.restaurant.longitude);
    const range = { ...row, confidence: "low" as const };
    return {
      ...row,
      distance_km: distance,
      fit: fit(range, p.budget),
      reason: reasoning(range, p.budget),
      score: score(range, p.budget),
    };
  }).filter((row) => row.distance_km <= p.radius_km)
    .sort((a, b) =>
      compareScores(a.score, b.score) || a.distance_km - b.distance_km || a.id.localeCompare(b.id)
    );
  return { options: options.map(({ score: _, ...row }) => row), dataset: "seeded" };
}
