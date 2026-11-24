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
 * What a model may reply with. Real menus are long and models leave out empty
 * fields, so this accepts more than [menuOutput] and [fitMenuReply] tightens it.
 */
export const menuReply = z.object({
  options: z.array(z.object({
    name: z.string(),
    portion: z.string().nullish(),
    printed_kcal: z.number().nullish(),
    calorie_evidence: z.string().nullish(),
  })),
});

/** Turns a loose reply into the strict shape, dropping what does not fit. */
export function fitMenuReply(reply: z.infer<typeof menuReply>): MenuExtraction {
  const text = (value: string | null | undefined, max: number) => {
    const t = (value ?? "").trim().slice(0, max);
    return t.length > 0 ? t : null;
  };
  return {
    options: reply.options
      .map((row) => ({
        name: text(row.name, 100),
        portion: text(row.portion, 100),
        printed_kcal: row.printed_kcal != null && Number.isInteger(row.printed_kcal) &&
            row.printed_kcal >= 15 && row.printed_kcal <= 6000
          ? row.printed_kcal
          : null,
        calorie_evidence: text(row.calorie_evidence, 120),
      }))
      .filter((row): row is MenuExtraction["options"][number] => row.name !== null)
      .slice(0, 18),
  };
}

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
