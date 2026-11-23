import { z } from "zod";
import {
  actions as coreActions,
  envelope,
  fail,
  ownedPath,
  photoPath,
  redact,
  targetPolicy,
  uuid,
  validateTarget,
} from "../_shared/contracts.ts";
import {
  authenticate,
  bucket,
  cached,
  cors,
  dataError,
  drainAssets,
  env,
  privateImage,
  provider,
  readLimited,
  response,
  rpc,
  type Session,
} from "../_shared/http.ts";

import { compare, compareInput, nearby, nearbyInput } from "../_shared/decision.ts";
import {
  correctionInput,
  editWaterInput,
  energy,
  energyInput,
  type Overview,
  summaryFacts,
  waterInput,
  weekly,
} from "../_shared/progress.ts";
import { assertAvailable, cleanup, erase } from "../_shared/privacy.ts";
import { audioRequest } from "../_shared/audio.ts";

const actions = {
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

async function run<A extends keyof typeof actions>(
  session: Session,
  action: A,
  input: z.infer<(typeof actions)[A]>,
) {
  const { uid, client, admin } = session;
  if (
    !["dashboard", "capabilities", "delete_data", "delete_account", "retry_media_cleanup"].includes(action)
  ) await assertAvailable(session);
  switch (action) {
    case "capabilities":
      return {
        live_ai: Boolean(provider.config.key && provider.config.kind === "openai"),
        bangla_text: env("PLATEWISE_BANGLA_TEXT_ENABLED") === "true",
        bangla_speech: env("PLATEWISE_BANGLA_SPEECH_ENABLED") === "true",
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
      if (p.language === "bn" && env("PLATEWISE_BANGLA_TEXT_ENABLED") !== "true") {
        fail(
          "LANGUAGE_UNAVAILABLE",
          "Live Bangla text analysis is unavailable. Enter the foods manually or use English.",
        );
      }
      const text = redact(p.description);
      return await cached(
        session,
        action,
        JSON.stringify([p.language, text]),
        () => provider.analyzeText(text, p.language),
      );
    }
    case "analyze_photo": {
      const p = input as z.infer<typeof actions.analyze_photo>;
      const image = await privateImage(session, p.image_storage_path);
      return await cached(session, action, image.bytes, () => provider.analyzePhoto(image));
    }
    case "weekly":
      return weekly(await rpc<Overview>(client, "pw_overview"));
    case "weekly_summary": {
      const aggregate = weekly(await rpc<Overview>(client, "pw_overview"));
      const facts = summaryFacts(aggregate);
      if (facts.length === 0) return { state: "insufficient", sentences: [] };
      return await cached(session, action, JSON.stringify(facts), async () => {
        const chosen = await provider.chooseFacts(facts);
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
      return await compare(session, input as z.infer<typeof compareInput>);
    case "nearby":
      return await nearby(session, input as z.infer<typeof nearbyInput>);
    case "extract_menu": {
      const p = input as z.infer<typeof actions.extract_menu>;
      const image = await privateImage(session, p.image_storage_path);
      return await cached(session, action, image.bytes, () => provider.extractMenu(image));
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
      const { data, error } = await client.from("asset_jobs").select("path").limit(100);
      if (error) dataError(error);
      await drainAssets(admin, data.map((row) => row.path));
      return { removed: true };
    }
    case "meal_image_url": {
      const p = input as z.infer<typeof actions.meal_image_url>;
      const { data: row, error } = await client.from("meals").select("image_storage_path").eq("id", p.id)
        .maybeSingle();
      if (error) dataError(error);
      if (!row?.image_storage_path) return fail("NOT_FOUND", "That photo is unavailable.", 404);
      const path = ownedPath(row.image_storage_path, uid);
      const { data, error: signingError } = await client.storage.from(bucket).createSignedUrl(path, 90);
      if (signingError || !data) return fail("NOT_FOUND", "That photo is unavailable.", 404);
      return { signed_url: data.signedUrl, expires_in: 90 };
    }
  }
}

export const handler = async (request: Request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(request) });
  const id = crypto.randomUUID();
  try {
    if (request.method !== "POST") fail("METHOD", "Use POST for this request.", 405);
    if (request.headers.has("x-platewise-cleanup")) return response(request, id, await cleanup(request));
    const session = await authenticate(request);
    const contentType = request.headers.get("Content-Type")?.toLowerCase() ?? "";
    if (contentType.startsWith("multipart/form-data;")) {
      await assertAvailable(session);
      return response(request, id, await audioRequest(session, request));
    }
    if (!contentType.startsWith("application/json")) fail("CONTENT_TYPE", "This request requires JSON.", 415);
    let json: unknown;
    try {
      json = JSON.parse(new TextDecoder().decode(await readLimited(request, 48 * 1024)));
    } catch (error) {
      if (error instanceof SyntaxError) fail("VALIDATION", "This JSON request could not be read.");
      throw error;
    }
    const parsed = envelope.safeParse(json);
    if (!parsed.success) return fail("VALIDATION", "Check the version and input of this request.");
    const action = parsed.data.action as keyof typeof actions;
    if (!Object.hasOwn(actions, action)) return fail("UNKNOWN_ACTION", "This action is unavailable.", 404);
    const input = actions[action].safeParse(parsed.data.input);
    if (!input.success) return fail("VALIDATION", "Check the values and try again.");
    return response(request, id, await run(session, action, input.data));
  } catch (error) {
    return response(request, id, null, error);
  }
};
