import { z } from "zod";

export class ApiError extends Error {
  constructor(readonly code: string, message: string, readonly status = 400, readonly retryable = false) {
    super(message);
  }
}
export const fail = (code: string, message: string, status = 400, retryable = false): never => {
  throw new ApiError(code, message, status, retryable);
};

export const uuid = z.uuid();
export const language = z.enum(["en", "bn"]);
export const photoPath = z.string().regex(/^[\da-f-]{36}\/[\da-f-]{36}\.(jpg|jpeg|png|webp)$/);
export const unit = z.enum(["g", "ml", "cup", "piece", "serving", "tbsp", "tsp", "oz", "slice", "bowl"]);
export const confidence = z.enum(["low", "medium", "high"]);
export const source = z.enum(["photo", "text", "voice", "menu", "comparison", "manual", "nearby"]);
export const nutrientKeys = ["protein_g", "carbohydrate_g", "fat_g", "fiber_g", "sodium_mg"] as const;
const nullableAmount = (max: number) => z.number().min(0).max(max).nullable();
const name = z.string().trim().min(1).max(100);
const boundedKcal = z.number().int().min(0).max(6000);

export const modelItem = z.strictObject({
  name,
  quantity: z.number().min(0.001).max(3000),
  unit,
  estimated_grams: nullableAmount(12000),
  calorie_low: boundedKcal,
  calorie_high: boundedKcal,
  protein_g: nullableAmount(1000),
  carbohydrate_g: nullableAmount(1500),
  fat_g: nullableAmount(1000),
  fiber_g: nullableAmount(300),
  sodium_mg: nullableAmount(50000),
});
const checkItem = (value: { calorie_low: number; calorie_high: number; quantity: number }) =>
  value.calorie_high >= value.calorie_low &&
  Math.abs(value.quantity * 1000 - Math.round(value.quantity * 1000)) < 1e-7;
export const item = modelItem.extend({
  normalized_food_reference: z.string().max(120).nullable().default(null),
  nutrient_source: z.enum(["unavailable", "model_estimate", "seeded", "reference", "manual"]),
  provenance: z.enum(["model", "demo", "manual", "menu_text", "reference", "scaled"]),
}).refine(checkItem, "Check calorie range and quantity precision.");
const assumptions = z.array(z.string().trim().min(1).max(200)).max(6);
export const modelEstimate = z.strictObject({
  items: z.array(modelItem.refine(checkItem)).max(16),
  confidence,
  assumptions,
  question: z.string().trim().min(1).max(200).nullable(),
});
export const meal = z.strictObject({
  id: uuid,
  source,
  image_storage_path: photoPath.nullable().default(null),
  confidence,
  assumptions,
  model: z.string().max(100).nullable().default(null),
  user_edited: z.boolean().default(false),
  items: z.array(item).min(1).max(16),
  expected_updated_at: z.iso.datetime({ offset: true }).nullable().optional(),
}).refine((m) => m.items.reduce((sum, x) => sum + x.calorie_high, 0) <= 20000, "Meal range is too large.");

export const targetPolicy = Object.freeze({ minimum: 1200, maximum: 5000, version: "adult-pilot-1" });
export const profile = z.strictObject({
  height_cm: z.number().min(100).max(250),
  weight_kg: z.number().min(30).max(350),
  daily_calorie_target: z.number().int().nullable(),
  water_goal_ml: z.number().int().min(500).max(5000).default(2000),
  timezone: z.string().min(1).max(80),
  preferred_units: z.enum(["metric", "us"]),
  preferred_language: language.default("en"),
  target_confirmed: z.boolean().default(false),
});
export const dishRecommendationInput = z.strictObject({
  dish: z.string().trim().min(2).max(300),
  language,
  budget: z.number().int().min(1).max(5000),
});
export const dishRecommendationOutput = z.strictObject({
  portion: z.string().trim().min(1).max(160),
  adjustments: z.array(z.string().trim().min(1).max(160)).max(4),
  calorie_low: boundedKcal,
  calorie_high: boundedKcal,
  confidence,
  assumptions,
}).refine((value) => value.calorie_high >= value.calorie_low, "Check calorie range.");

export const actions = {
  capabilities: z.strictObject({}),
  dashboard: z.strictObject({}),
  update_profile: profile,
  analyze_text: z.strictObject({ description: z.string().trim().min(2).max(600), language }),
  recommend_dish: dishRecommendationInput,
  analyze_photo: z.strictObject({ image_storage_path: photoPath }),
  confirm_meal: meal,
  edit_meal: meal,
  delete_meal: z.strictObject({ id: uuid }),
  discard_photo: z.strictObject({ image_storage_path: photoPath }),
  retry_media_cleanup: z.strictObject({}),
  meal_image_url: z.strictObject({ id: uuid }),
};
export const envelope = z.strictObject({
  version: z.literal(1),
  action: z.string().min(1).max(40),
  input: z.unknown(),
});

export function validateTarget(p: z.infer<typeof profile>) {
  const n = p.daily_calorie_target;
  if (n !== null && (n < targetPolicy.minimum || n > targetPolicy.maximum)) {
    fail(
      "TARGET_RANGE",
      "That target is outside the 1,200–5,000 kcal pilot range. You can keep logging without a target. Please speak with a qualified healthcare professional about your individual calorie needs, especially if a target below 1,200 kcal seems necessary.",
    );
  }
  if (n !== null && !p.target_confirmed) {
    fail(
      "TARGET_CONFIRMATION",
      "Confirm that the adult target guidance applies to you, or continue without a target.",
    );
  }
  try {
    new Intl.DateTimeFormat("en", { timeZone: p.timezone });
  } catch {
    fail("INVALID_TIMEZONE", "Enter a supported IANA timezone, such as Asia/Dhaka.");
  }
}

export function estimate(result: z.infer<typeof modelEstimate>, model: string) {
  if (result.items.length === 0) {
    fail(
      "UNCLEAR_MEAL",
      "The food or portion was unclear. Try a clearer photo or describe the meal and its portions.",
    );
  }
  const items = result.items.map((i) => ({
    ...i,
    name: redact(i.name).slice(0, 100) || "Food item",
    normalized_food_reference: null,
    nutrient_source: nutrientKeys.some((key) => i[key] !== null)
      ? "model_estimate" as const
      : "unavailable" as const,
    provenance: "model" as const,
  }));
  const low = items.reduce((n, i) => n + i.calorie_low, 0);
  const high = items.reduce((n, i) => n + i.calorie_high, 0);
  if (high > 20000 || high === 0) {
    fail(
      "INVALID_ESTIMATE",
      "The estimate was outside the supported range. Try describing the meal or entering it manually.",
      422,
    );
  }
  return {
    items,
    confidence: result.confidence === "high" ? "medium" : result.confidence,
    assumptions: result.assumptions.map((value) => redact(value).slice(0, 200)),
    question: result.question === null ? null : redact(result.question).slice(0, 200),
    calorie_low: low,
    calorie_high: high,
    representative_calories: Math.round((low + high) / 2),
    model,
  };
}

export function redact(input: string) {
  return input.replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, "[contact removed]")
    .replace(/\b(?:https?:\/\/|www\.)\S+/gi, "[link removed]")
    .replace(/(?:\+?\d[\d(). -]{7,}\d)/g, "[number removed]")
    .replace(/\b(?:my name is|name:)\s+[\p{L}\p{M} .'-]+/giu, "[name removed]")
    // deno-lint-ignore no-control-regex
    .replace(/[\u0000-\u0008\u000b\u000e-\u001f]/g, "")
    .trim();
}

export function ownedPath(path: string, userId: string): string {
  if (!photoPath.safeParse(path).success || path.split("/")[0] !== userId) {
    fail("NOT_FOUND", "That photo is unavailable.", 404);
  }
  return path;
}

export function validateImage(bytes: Uint8Array, path: string) {
  if (bytes.length < 12 || bytes.length > 5 * 1024 * 1024) {
    fail("IMAGE_SIZE", "Choose an image up to 5 MB.");
  }
  const jpg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const png = [137, 80, 78, 71, 13, 10, 26, 10].every((v, index) => bytes[index] === v);
  const webp = [82, 73, 70, 70].every((v, index) => bytes[index] === v) &&
    [87, 69, 66, 80].every((v, index) => bytes[index + 8] === v);
  if (jpg && /\.jpe?g$/.test(path)) return "image/jpeg";
  if (png && path.endsWith(".png")) return "image/png";
  if (webp && path.endsWith(".webp")) return "image/webp";
  return fail("IMAGE_TYPE", "Choose a JPEG, PNG or WebP image.");
}

export function dayKey(instant: Date, zone: string) {
  const parts = new Intl.DateTimeFormat("en", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  })
    .formatToParts(instant);
  const part = (type: string) => parts.find((p) => p.type === type)?.value;
  return [part("year"), part("month"), part("day")].join("-");
}
