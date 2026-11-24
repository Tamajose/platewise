import { z } from "zod";
import { fail, redact } from "./contracts.ts";

export const menuOutput = z.strictObject({
  options: z.array(z.strictObject({
    name: z.string().trim().min(1).max(100),
    portion: z.string().trim().max(100).nullable(),
    printed_kcal: z.number().int().min(15).max(6000).nullable(),
    calorie_evidence: z.string().trim().max(120).nullable(),
  })).max(18),
});
export type MenuExtraction = z.infer<typeof menuOutput>;

/**
 * Treats a model's menu reading as untrusted. A calorie value counts only when
 * the quoted evidence names that same number as kcal or calories, and prices
 * never do.
 */
export function normalizeMenu(output: MenuExtraction): MenuExtraction {
  const clean = output.options.map((row) => {
    const labelled = row.calorie_evidence?.match(
      /\b(\d[\d,]*)\s*(?:kcal|calories?)\b|\b(?:kcal|calories?)\s*[:=]?\s*(\d[\d,]*)\b/i,
    );
    const evidenceValue = Number((labelled?.[1] ?? labelled?.[2] ?? "").replaceAll(",", ""));
    const verifiedLabel = row.printed_kcal !== null && evidenceValue === row.printed_kcal &&
      !/[$৳€£]|(?:\b(?:bdt|tk|price)\b)/i.test(row.calorie_evidence ?? "");
    return {
      name: redact(row.name).slice(0, 100),
      portion: row.portion === null ? null : redact(row.portion).slice(0, 100),
      printed_kcal: verifiedLabel ? row.printed_kcal : null,
      calorie_evidence: verifiedLabel ? row.calorie_evidence : null,
    };
  }).filter((row) => row.name.length > 0);
  if (clean.length === 0) {
    fail(
      "UNCLEAR_MENU",
      "No meal names could be read. Try a clearer picture or enter the dishes yourself.",
      422,
    );
  }
  return { options: clean };
}
