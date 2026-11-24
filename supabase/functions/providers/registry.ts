import type { AiProviders, Capability, ImageInput, Language } from "../domain/ports.ts";
import { SpeechAdapter, TextAdapter, UnavailableAdapter, VisionAdapter } from "./adapters.ts";
import { ChatClient, type ProviderProfile, type StructuredMode } from "./chat_client.ts";
import { GeminiSpeechClient, type TranscriptionClient } from "./gemini_speech.ts";

/**
 * The services PlateWise can talk to. Each offers OpenAI-style endpoints. Add a
 * profile here to support another one that does.
 *
 * Model names are defaults only and change often. Set PLATEWISE_VISION_MODEL,
 * PLATEWISE_TEXT_MODEL and PLATEWISE_SPEECH_MODEL to choose others. Groq has no
 * default vision model, because the one it offered was retired: set one that
 * accepts images, or choose another provider for vision.
 */
export const profiles: Readonly<Record<string, ProviderProfile>> = {
  openai: {
    name: "openai",
    baseUrl: "https://api.openai.com/v1/",
    keyVariable: "OPENAI_API_KEY",
    speechApi: "transcriptions",
    nativeBaseUrl: null,
    structured: "strict",
    sendStoreFalse: true,
    maxReplyTokens: 3200,
    imageDetail: "high",
    defaults: { vision: "gpt-4.1-mini", text: "gpt-4.1-mini", speech: "gpt-4o-mini-transcribe" },
  },
  groq: {
    name: "groq",
    baseUrl: "https://api.groq.com/openai/v1/",
    keyVariable: "GROQ_API_KEY",
    speechApi: "transcriptions",
    nativeBaseUrl: null,
    structured: "schema",
    sendStoreFalse: false,
    maxReplyTokens: 3200,
    imageDetail: null,
    defaults: { vision: null, text: "openai/gpt-oss-120b", speech: "whisper-large-v3-turbo" },
  },
  // Gemini's OpenAI-compatible endpoint takes chat completions with images. Its
  // support for response schemas is unclear, so replies are requested in the prompt
  // and validated here. Thinking models can spend a token cap on reasoning, so no
  // cap is sent. That endpoint has no /audio/transcriptions route, so speech uses
  // Gemini's own API, where the recording is sent with an instruction.
  gemini: {
    name: "gemini",
    baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai/",
    keyVariable: "GEMINI_API_KEY",
    speechApi: "gemini",
    nativeBaseUrl: "https://generativelanguage.googleapis.com/v1beta/",
    structured: "prompt",
    sendStoreFalse: false,
    maxReplyTokens: null,
    imageDetail: null,
    defaults: {
      vision: "gemini-3.5-flash-lite",
      text: "gemini-3.5-flash-lite",
      speech: "gemini-3.5-flash-lite",
    },
  },
};

type Get = (name: string) => string | undefined;

const modelVariable = {
  vision: "PLATEWISE_VISION_MODEL",
  text: "PLATEWISE_TEXT_MODEL",
  speech: "PLATEWISE_SPEECH_MODEL",
} as const;
const providerVariable = {
  vision: "PLATEWISE_VISION_PROVIDER",
  text: "PLATEWISE_TEXT_PROVIDER",
  speech: "PLATEWISE_SPEECH_PROVIDER",
} as const;

function structuredMode(get: Get, profile: ProviderProfile): StructuredMode {
  const chosen = get("PLATEWISE_STRUCTURED_OUTPUT");
  return chosen === "strict" || chosen === "schema" || chosen === "json" || chosen === "prompt"
    ? chosen
    : profile.structured;
}

/** A capability's client and model, or null when it lacks a service, key or model. */
function resolve(capability: Capability, get: Get, network: typeof fetch, timeout?: number) {
  const name = get(providerVariable[capability]) ?? get("PLATEWISE_AI_PROVIDER") ?? "openai";
  const profile = profiles[name];
  const key = profile ? get(profile.keyVariable) ?? "" : "";
  const model = get(modelVariable[capability]) ?? profile?.defaults[capability] ?? null;
  if (!profile || !key || !model) return { name, model: model ?? "", client: null, transcriber: null };
  const transcriber: TranscriptionClient = profile.speechApi === "gemini"
    ? new GeminiSpeechClient(profile, key, network, timeout)
    : new ChatClient(profile, key, structuredMode(get, profile), network, timeout);
  return {
    name,
    model,
    client: new ChatClient(profile, key, structuredMode(get, profile), network, timeout),
    transcriber,
  };
}

/**
 * Builds the AI services from the environment. Vision, text and speech can
 * each use a different provider, so one provider's gap does not disable the
 * others. A capability without a key or model reports itself unavailable.
 */
export function createAiProviders(
  get: Get,
  network: typeof fetch = fetch,
  timeout?: number,
): AiProviders {
  const vision = resolve("vision", get, network, timeout);
  const text = resolve("text", get, network, timeout);
  const speech = resolve("speech", get, network, timeout);
  const none = new UnavailableAdapter();
  const visionAdapter = vision.client ? new VisionAdapter(vision.client, vision.model) : none;
  const textAdapter = text.client ? new TextAdapter(text.client, text.model) : none;
  const speechAdapter = speech.transcriber ? new SpeechAdapter(speech.transcriber, speech.model) : none;
  const ready = { vision: !!vision.client, text: !!text.client, speech: !!speech.transcriber };
  return {
    available: (capability) => ready[capability],
    identity: {
      kind: [vision.name, text.name, speech.name].join("+"),
      vision: vision.model,
      text: text.model,
    },
    analyzePhoto: (image: ImageInput) => visionAdapter.analyzePhoto(image),
    extractMenu: (image: ImageInput) => visionAdapter.extractMenu(image),
    analyzeText: (value: string, language: Language) => textAdapter.analyzeText(value, language),
    recommendDish: (value: string, language: Language, budget: number) =>
      textAdapter.recommendDish(value, language, budget),
    chooseFacts: (facts) => textAdapter.chooseFacts(facts),
    transcribe: (audio: File, language: Language) => speechAdapter.transcribe(audio, language),
  };
}
