import type { z } from "zod";
import { fail, redact } from "../domain/contracts.ts";
import { type Attempt, type compareInput, printedEstimate, rankAttempts } from "../domain/decision.ts";
import type { MealEstimate, Services } from "../domain/ports.ts";
import { cached } from "../infra/cache.ts";
import { privateImage, type Session } from "../infra/supabase.ts";

/**
 * Estimates two or three options and ranks them for a budget. One option that
 * cannot be estimated is reported on its own and does not stop the others.
 */
export async function compare(session: Session, p: z.infer<typeof compareInput>, services: Services) {
  const { ai, flags } = services;
  const attempts: Attempt[] = await Promise.all(p.options.map(async (option, index) => {
    try {
      let result: MealEstimate;
      if (option.kind === "photo") {
        const image = await privateImage(session, option.image_storage_path);
        result = await cached(
          session,
          ai,
          "vision",
          "analyze_photo",
          image.bytes,
          () => ai.analyzePhoto(image),
        );
      } else if (option.printed_kcal !== null) {
        result = printedEstimate(option.name, option.portion, option.printed_kcal);
      } else {
        if (option.language === "bn" && !flags.banglaText) {
          fail(
            "LANGUAGE_UNAVAILABLE",
            "Bangla analysis is unavailable. Try English or enter the estimate manually.",
          );
        }
        const text = redact([option.name, option.portion].filter(Boolean).join(", "));
        const estimated = await cached(
          session,
          ai,
          "text",
          "analyze_text",
          JSON.stringify([option.language, text]),
          () => ai.analyzeText(text, option.language),
        );
        result = {
          ...estimated,
          assumptions: ["Nutrition inferred from the menu name and portion.", ...estimated.assumptions].slice(
            0,
            6,
          ),
        };
      }
      return {
        key: option.key,
        index,
        estimate: result,
        image_storage_path: option.kind === "photo" ? option.image_storage_path : null,
        error: null,
      };
    } catch (error) {
      const known = error instanceof Error && "code" in error && typeof error.code === "string" &&
        "retryable" in error;
      return {
        key: option.key,
        index,
        estimate: null,
        image_storage_path: null,
        error: {
          code: known ? String(error.code) : "OPTION_FAILED",
          message: known ? error.message : "This option could not be estimated.",
          retryable: known && error.retryable === true,
        },
      };
    }
  }));
  return rankAttempts(attempts, p.budget);
}
