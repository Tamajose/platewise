import { z } from "zod";
import { ApiError, fail } from "../domain/contracts.ts";

/**
 * How strictly a service enforces a response schema.
 * - `strict`: the service must follow the JSON schema exactly.
 * - `schema`: the service tries to follow the JSON schema and may not.
 * - `json`: the service only promises valid JSON, so the schema goes in the prompt.
 * - `prompt`: no response format is requested at all. The schema goes in the prompt
 *   and the reply is read as JSON, with or without a code fence. This works on any
 *   chat model, which makes it the safe choice for a service whose support for the
 *   other modes is unclear.
 * The reply is always validated again here, whatever the service promises.
 */
export type StructuredMode = "strict" | "schema" | "json" | "prompt";

/** What differs between services that speak the same chat and transcription API. */
export interface ProviderProfile {
  readonly name: string;
  /** Ends with a slash. */
  readonly baseUrl: string;
  readonly keyVariable: string;
  /**
   * Where recordings go. `transcriptions` is the OpenAI-style audio route.
   * `gemini` sends the recording to Gemini's own API, which has no such route.
   */
  readonly speechApi: "transcriptions" | "gemini";
  /** Gemini's own API address, with a trailing slash. Null for other services. */
  readonly nativeBaseUrl: string | null;
  readonly structured: StructuredMode;
  /** Asks the service not to keep the request. Not every service accepts the field. */
  readonly sendStoreFalse: boolean;
  /** Caps the reply length with `max_completion_tokens`, or sends no cap when null. */
  readonly maxReplyTokens: number | null;
  /** Image detail level, for services that accept one. */
  readonly imageDetail: "high" | null;
  readonly defaults: {
    readonly vision: string | null;
    readonly text: string | null;
    readonly speech: string | null;
  };
}

export async function withRetry<T>(operation: () => Promise<T>, delay = 220): Promise<T> {
  try {
    return await operation();
  } catch (err) {
    if (!(err instanceof ApiError) || !err.retryable) throw err;
    await new Promise((resolve) => setTimeout(resolve, delay));
    return await operation();
  }
}

/**
 * Reads a model's reply as JSON. Some models wrap it in a code fence or add a
 * sentence around it, so fall back to the outermost braces.
 */
export function parseJsonReply(content: string): unknown {
  try {
    return JSON.parse(content);
  } catch {
    const fenced = content.match(/```(?:json)?\s*([\s\S]*?)```/i)?.[1] ?? content;
    const start = fenced.indexOf("{");
    const end = fenced.lastIndexOf("}");
    if (start < 0 || end <= start) throw new SyntaxError("No JSON object in the reply.");
    return JSON.parse(fenced.slice(start, end + 1));
  }
}

export function base64(bytes: Uint8Array) {
  const pieces = [];
  for (let offset = 0; offset < bytes.length; offset += 16384) {
    pieces.push(String.fromCharCode(...bytes.subarray(offset, offset + 16384)));
  }
  return btoa(pieces.join(""));
}

/** The schema without the keywords that strict structured outputs reject. */
export function providerSchema(schema: z.ZodType) {
  const restrictiveKeywords = new Set([
    "$schema",
    "minimum",
    "maximum",
    "minLength",
    "maxLength",
    "minItems",
    "maxItems",
    "pattern",
    "format",
  ]);
  return JSON.parse(
    JSON.stringify(z.toJSONSchema(schema), (key, value) => restrictiveKeywords.has(key) ? undefined : value),
  );
}

/**
 * Sends one request to an AI service and returns its JSON answer. Timeouts,
 * connection failures and error statuses become API errors that are safe to
 * show, and a busy or failing service is tried once more.
 */
export async function postToService(
  network: typeof fetch,
  timeout: number,
  url: string,
  init: Omit<RequestInit, "signal">,
  /** Whether a busy or timed-out service is tried once more. */
  retry = true,
) {
  const attempt = async () => {
    let response: Response;
    try {
      response = await network(url, { ...init, signal: AbortSignal.timeout(timeout) });
    } catch (error) {
      if (error instanceof DOMException && ["TimeoutError", "AbortError"].includes(error.name)) {
        return fail(
          "AI_TIMEOUT",
          "Analysis took longer than expected. Try again or enter the meal manually.",
          504,
          true,
        );
      }
      return fail(
        "AI_OFFLINE",
        "The analysis service could not be reached. Try again or enter the meal manually.",
        503,
        true,
      );
    }
    if (!response.ok) {
      await response.body?.cancel();
      if (response.status === 429 || response.status >= 500) {
        return fail(
          "AI_BUSY",
          "Analysis is temporarily busy. Try again or enter the meal manually.",
          503,
          true,
        );
      }
      return fail(
        "AI_UNAVAILABLE",
        "Live analysis is unavailable for this input. You can enter the meal manually.",
        502,
      );
    }
    try {
      return await response.json();
    } catch {
      return fail(
        "INVALID_ESTIMATE",
        "The analysis could not be read. You can enter the meal manually.",
        422,
      );
    }
  };
  return retry ? await withRetry(attempt) : await attempt();
}

/**
 * Talks to a service that offers OpenAI-style chat completions and audio
 * transcriptions. Every failure becomes an API error that is safe to show.
 */
export class ChatClient {
  constructor(
    readonly profile: ProviderProfile,
    private readonly key: string,
    private readonly mode: StructuredMode,
    private readonly network: typeof fetch = fetch,
    private readonly timeout = 8500,
  ) {}

  private async request(path: string, body: unknown, multipart = false) {
    return await postToService(this.network, this.timeout, this.profile.baseUrl + path, {
      method: "POST",
      headers: {
        Authorization: "Bearer " + this.key,
        ...(multipart ? {} : { "Content-Type": "application/json" }),
      },
      body: multipart ? body as FormData : JSON.stringify(body),
    });
  }

  /** Asks for a reply that matches [schema] and returns it, validated. */
  async structured<T>(
    model: string,
    name: string,
    instructions: string,
    content: unknown,
    schema: z.ZodType<T>,
  ): Promise<T> {
    const jsonSchema = providerSchema(schema);
    const system = this.mode === "json" || this.mode === "prompt"
      ? instructions + " Reply with one JSON object that matches this JSON Schema: " +
        JSON.stringify(jsonSchema)
      : instructions;
    const response = await this.request("chat/completions", {
      model,
      ...(this.profile.sendStoreFalse ? { store: false } : {}),
      temperature: 0,
      ...(this.profile.maxReplyTokens === null ? {} : { max_completion_tokens: this.profile.maxReplyTokens }),
      messages: [
        { role: "system", content: system },
        { role: "user", content },
      ],
      ...(this.mode === "prompt" ? {} : {
        response_format: this.mode === "json" ? { type: "json_object" } : {
          type: "json_schema",
          json_schema: { name, strict: this.mode === "strict", schema: jsonSchema },
        },
      }),
    });
    const entry = response?.choices?.[0];
    let answer: unknown;
    try {
      if (entry?.finish_reason !== "stop" || entry.message?.refusal) throw new Error();
      answer = parseJsonReply(entry.message.content);
    } catch {
      return fail(
        "INVALID_ESTIMATE",
        "The analysis did not return a usable result. Try again or enter the meal manually.",
        422,
      );
    }
    const parsed = schema.safeParse(answer);
    if (!parsed.success) {
      return fail(
        "INVALID_ESTIMATE",
        "The estimate failed validation. Try a clearer input or enter it manually.",
        422,
      );
    }
    return parsed.data;
  }

  /** Content parts for a message that holds a picture and an instruction. */
  imageContent(bytes: Uint8Array, mime: string, text: string) {
    const url = "data:" + mime + ";base64," + base64(bytes);
    return [
      { type: "text", text },
      {
        type: "image_url",
        image_url: this.profile.imageDetail ? { url, detail: this.profile.imageDetail } : { url },
      },
    ];
  }

  /** Transcribes a recording and returns the text the service heard. */
  async transcribe(model: string, audio: File, language: string): Promise<unknown> {
    const form = new FormData();
    form.set("file", audio, audio.name);
    form.set("model", model);
    form.set("language", language);
    form.set("response_format", "json");
    const response = await this.request("audio/transcriptions", form, true);
    return response?.text;
  }
}
