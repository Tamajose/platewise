import { z } from "zod";
import { fail, language } from "./contracts.ts";
import { env, provider, readLimited, reserve, type Session } from "./http.ts";

export function audioKind(bytes: Uint8Array) {
  const ascii = (offset: number, count: number) =>
    String.fromCharCode(...bytes.subarray(offset, offset + count));
  if (bytes.length < 24) return null;
  if (ascii(4, 4) === "ftyp") return { name: "meal.m4a", type: "audio/mp4" };
  if (bytes[0] === 0x1a && bytes[1] === 0x45 && bytes[2] === 0xdf && bytes[3] === 0xa3) {
    return { name: "meal.webm", type: "audio/webm" };
  }
  if (ascii(0, 4) === "RIFF" && ascii(8, 4) === "WAVE") return { name: "meal.wav", type: "audio/wav" };
  return null;
}
export async function audioRequest(session: Session, request: Request) {
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
  if (lang.data === "bn" && env("PLATEWISE_BANGLA_SPEECH_ENABLED") !== "true") {
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
  await reserve(session);
  const transcript = await provider.transcribe(new File([sample], kind.name, { type: kind.type }), lang.data);
  return { transcript: z.string().max(1200).parse(transcript) };
}
