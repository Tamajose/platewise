import type { Flags } from "../domain/ports.ts";

/** Reads one environment variable. */
export const env = (key: string) => Deno.env.get(key);

/** Language switches, which stay off until a language has been tested. */
export function readFlags(get: (name: string) => string | undefined = env): Flags {
  return {
    banglaText: get("PLATEWISE_BANGLA_TEXT_ENABLED") === "true",
    banglaSpeech: get("PLATEWISE_BANGLA_SPEECH_ENABLED") === "true",
  };
}
