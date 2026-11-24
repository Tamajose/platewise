import { z } from "zod";
import { fail, language } from "../domain/contracts.ts";
import { audioKind } from "../domain/media.ts";
import type { Services } from "../domain/ports.ts";
import { reserve } from "../infra/cache.ts";
import type { Session } from "../infra/supabase.ts";
import { readLimited } from "../infra/web.ts";

/** Transcribes one short voice note sent as a multipart form. */
export async function audioRequest(session: Session, request: Request, services: Services) {
  const { ai, flags } = services;
  const maxAudio = 2 * 1024 * 1024;
  const bytes = await readLimited(request, maxAudio + 8192);
  let form: FormData;
  try {
    form = await new Response(bytes, { headers: { "Content-Type": request.headers.get("Content-Type")! } })
      .formData();
  } catch {
    return fail("INVALID_AUDIO", "The recording could not be read. Try again or type your meal.");
  }
  const lang = language.safeParse(form.get("language"));
  if (
    !lang.success || form.get("version") !== "1" || form.get("action") !== "transcribe_voice" ||
    form.getAll("audio").length !== 1
  ) {
    return fail("VALIDATION", "Check the recording and language.");
  }
  if (lang.data === "bn" && !flags.banglaSpeech) {
    return fail(
      "LANGUAGE_UNAVAILABLE",
      "Bangla speech is unavailable. Speak in English or type the meal manually.",
    );
  }
  const file = form.get("audio");
  if (!(file instanceof File) || file.size > maxAudio) {
    return fail("INVALID_AUDIO", "Use a short recording up to 2 MB or type your meal.");
  }
  const sample = new Uint8Array(await file.arrayBuffer());
  const kind = audioKind(sample);
  if (!kind) return fail("AUDIO_TYPE", "Use a supported M4A, WebM, or WAV recording.");
  await reserve(session, ai, "speech");
  const transcript = await ai.transcribe(new File([sample], kind.name, { type: kind.type }), lang.data);
  return { transcript: z.string().max(1200).parse(transcript) };
}
