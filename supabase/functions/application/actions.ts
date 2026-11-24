import { z } from "zod";
import {
  actions as coreActions,
  fail,
  ownedPath,
  photoPath,
  redact,
  targetPolicy,
  uuid,
  validateTarget,
} from "../domain/contracts.ts";
import { compareInput, nearbyInput } from "../domain/decision.ts";
import type { Services } from "../domain/ports.ts";
import {
  correctionInput,
  editWaterInput,
  energy,
  energyInput,
  type Overview,
  summaryFacts,
  waterInput,
  weekly,
} from "../domain/progress.ts";
import { cached } from "../infra/cache.ts";
import {
  drainAssets,
  pendingCleanupPaths,
  privateImage,
  rpc,
  type Session,
  signedPhotoUrl,
} from "../infra/supabase.ts";
import { audioRequest } from "./audio.ts";
import { compare } from "./compare.ts";
import { nearby } from "./nearby.ts";
import { assertAvailable, cleanup, erase } from "./privacy.ts";

export { audioRequest, cleanup };

/** Every action of API v1 with the schema that checks its input. */
export const actions = {
  ...coreActions,
  compare: compareInput,
  weekly: z.strictObject({}),
  weekly_summary: z.strictObject({}),
  log_water: waterInput,
  edit_water: editWaterInput,
  delete_water: z.strictObject({ id: uuid }),
  estimate_energy: energyInput,
  correction_consent: z.strictObject({ enabled: z.boolean() }),
  share_correction: correctionInput,
  delete_data: z.strictObject({}),
  delete_account: z.strictObject({}),
  nearby: nearbyInput,
  extract_menu: z.strictObject({ image_storage_path: photoPath }),
};
export type ActionName = keyof typeof actions;

const unguarded = ["dashboard", "capabilities", "delete_data", "delete_account", "retry_media_cleanup"];

/** Performs one action for a signed-in person. [input] has already passed its schema. */
export async function run<A extends ActionName>(
  session: Session,
  action: A,
  input: z.infer<(typeof actions)[A]>,
  services: Services,
) {
  const { uid, client, admin } = session;
  const { ai, flags } = services;
  if (!unguarded.includes(action)) await assertAvailable(session);
  switch (action) {
    case "capabilities":
      return {
        live_ai: ai.available("text") || ai.available("vision") || ai.available("speech"),
        live_vision: ai.available("vision"),
        live_text: ai.available("text"),
        live_speech: ai.available("speech"),
        bangla_text: flags.banglaText,
        bangla_speech: flags.banglaSpeech,
        target_policy: targetPolicy,
      };
    case "dashboard":
      return await rpc(client, "pw_overview");
    case "update_profile": {
      const p = input as z.infer<typeof actions.update_profile>;
      validateTarget(p);
      return await rpc(admin, "pw_profile_write", { p_user: uid, p_data: p });
    }
    case "analyze_text": {
      const p = input as z.infer<typeof actions.analyze_text>;
      if (p.language === "bn" && !flags.banglaText) {
        fail(
          "LANGUAGE_UNAVAILABLE",
          "Live Bangla text analysis is unavailable. Enter the foods manually or use English.",
        );
      }
      const text = redact(p.description);
      return await cached(
        session,
        ai,
        "text",
        action,
        JSON.stringify([p.language, text]),
        () => ai.analyzeText(text, p.language),
      );
    }
    case "recommend_dish": {
      const p = input as z.infer<typeof actions.recommend_dish>;
      if (p.language === "bn" && !flags.banglaText) {
        fail(
          "LANGUAGE_UNAVAILABLE",
          "Live Bangla dish planning is unavailable. Enter the dish in English.",
        );
      }
      const dish = redact(p.dish);
      return await cached(
        session,
        ai,
        "text",
        action,
        JSON.stringify([p.language, dish, p.budget]),
        () => ai.recommendDish(dish, p.language, p.budget),
      );
    }
    case "analyze_photo": {
      const p = input as z.infer<typeof actions.analyze_photo>;
      const image = await privateImage(session, p.image_storage_path);
      return await cached(session, ai, "vision", action, image.bytes, () => ai.analyzePhoto(image));
    }
    case "weekly":
      return weekly(await rpc<Overview>(client, "pw_overview"));
    case "weekly_summary": {
      const aggregate = weekly(await rpc<Overview>(client, "pw_overview"));
      const facts = summaryFacts(aggregate);
      if (facts.length === 0) return { state: "insufficient", sentences: [] };
      return await cached(session, ai, "text", action, JSON.stringify(facts), async () => {
        const chosen = await ai.chooseFacts(facts);
        if (chosen.length === 0) {
          fail(
            "INVALID_SUMMARY",
            "A weekly summary could not be prepared. Your logged figures are available.",
          );
        }
        return { state: "generated", sentences: chosen.map((i) => facts[i]) };
      });
    }
    case "log_water":
    case "edit_water":
    case "delete_water":
      return await rpc(admin, "pw_water_write", { p_user: uid, p_action: action, p_data: input });
    case "estimate_energy":
      return energy(await rpc<Overview>(client, "pw_overview"), input as z.infer<typeof energyInput>);
    case "correction_consent":
    case "share_correction":
      return await rpc(admin, "pw_share", { p_user: uid, p_action: action, p_data: input });
    case "delete_data":
    case "delete_account":
      return await erase(session, action === "delete_account");
    case "compare":
      return await compare(session, input as z.infer<typeof compareInput>, services);
    case "nearby":
      return await nearby(session, input as z.infer<typeof nearbyInput>);
    case "extract_menu": {
      const p = input as z.infer<typeof actions.extract_menu>;
      const image = await privateImage(session, p.image_storage_path);
      return await cached(session, ai, "vision", action, image.bytes, () => ai.extractMenu(image));
    }
    case "confirm_meal":
    case "edit_meal": {
      const p = input as z.infer<typeof actions.confirm_meal>;
      if (p.image_storage_path) ownedPath(p.image_storage_path, uid);
      return await rpc(admin, "pw_meal_write", { p_user: uid, p_action: action, p_data: p });
    }
    case "delete_meal":
    case "discard_photo": {
      const paths = await rpc<{ paths: string[] }>(admin, "pw_meal_write", {
        p_user: uid,
        p_action: action,
        p_data: input,
      });
      await drainAssets(admin, paths.paths);
      return { removed: true };
    }
    case "retry_media_cleanup": {
      await drainAssets(admin, await pendingCleanupPaths(client));
      return { removed: true };
    }
    case "meal_image_url": {
      const p = input as z.infer<typeof actions.meal_image_url>;
      return await signedPhotoUrl(client, uid, p.id);
    }
  }
}
