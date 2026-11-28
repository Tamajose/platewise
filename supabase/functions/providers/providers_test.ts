// deno-lint-ignore-file no-explicit-any
import assert from "node:assert/strict";
import { ApiError } from "../domain/contracts.ts";
import { parseJsonReply, withRetry } from "./chat_client.ts";
import { createAiProviders, profiles } from "./registry.ts";

const food = {
  name: "Rice",
  quantity: 1,
  unit: "cup",
  estimated_grams: 160,
  calorie_low: 180,
  calorie_high: 241,
  protein_g: 4,
  carbohydrate_g: null,
  fat_g: null,
  fiber_g: null,
  sodium_mg: null,
};
const meal = { items: [food], confidence: "high", assumptions: ["Cooked rice"], question: null };
const environment = (values: Record<string, string | undefined>) => (name: string) => values[name];

/** A network that records requests and answers a chat completion. */
function recorder(content: unknown = meal) {
  const calls: { url: string; headers: Headers; body: Record<string, unknown> | FormData }[] = [];
  const network: typeof fetch = (input, init) => {
    const body = init?.body instanceof FormData ? init.body : JSON.parse(init?.body as string);
    calls.push({ url: String(input), headers: new Headers(init?.headers), body });
    return Promise.resolve(
      Response.json(
        body instanceof FormData ? { text: "one cup of rice" } : {
          choices: [{
            finish_reason: "stop",
            message: { content: typeof content === "string" ? content : JSON.stringify(content) },
          }],
        },
      ),
    );
  };
  return { calls, network };
}

Deno.test("OpenAI requests are strict, unstored, free of contact details and treat input as untrusted", async () => {
  const { calls, network } = recorder();
  const ai = createAiProviders(
    environment({ OPENAI_API_KEY: "local-test-value", PLATEWISE_TEXT_MODEL: "fixture-model" }),
    network,
  );
  const result = await ai.analyzeText("Rice, person@example.org", "en");
  assert.equal(result.calorie_high, 241);
  assert.equal(result.model, "fixture-model");
  const [call] = calls;
  const body = call.body as Record<string, any>;
  assert.equal(call.url, "https://api.openai.com/v1/chat/completions");
  assert.equal(call.headers.get("Authorization"), "Bearer local-test-value");
  assert.equal(body.store, false);
  assert.equal(body.response_format.json_schema.strict, true);
  assert.equal(body.tools, undefined);
  assert.match(body.messages[0].content, /untrusted/);
  assert.doesNotMatch(body.messages[1].content, /example.org/);
});

Deno.test("Groq uses its own address and key, does not send store, and asks for a non-strict schema", async () => {
  const { calls, network } = recorder();
  const ai = createAiProviders(
    environment({ PLATEWISE_AI_PROVIDER: "groq", GROQ_API_KEY: "groq-test-value" }),
    network,
  );
  await ai.analyzeText("Rice and dal", "en");
  const [call] = calls;
  const body = call.body as Record<string, any>;
  assert.equal(call.url, "https://api.groq.com/openai/v1/chat/completions");
  assert.equal(call.headers.get("Authorization"), "Bearer groq-test-value");
  assert.equal(body.model, profiles.groq.defaults.text);
  assert.equal("store" in body, false);
  assert.equal(body.response_format.type, "json_schema");
  assert.equal(body.response_format.json_schema.strict, false);
});

Deno.test("low-confidence photos are blocked while text estimates remain available", async () => {
  const lowConfidence = {
    ...meal,
    confidence: "low",
  };
  const photo = recorder(lowConfidence);
  const photoAi = createAiProviders(
    environment({ OPENAI_API_KEY: "local-test-value", PLATEWISE_VISION_MODEL: "fixture-model" }),
    photo.network,
  );
  await assert.rejects(
    photoAi.analyzePhoto({ bytes: new Uint8Array([1, 2, 3]), mime: "image/jpeg" }),
    (error: ApiError) =>
      error.code === "LOW_CONFIDENCE_PHOTO" &&
      /clearer photo.*describe the dishes and portions.*manually.*qualified healthcare professional/.test(
        error.message,
      ),
  );
  const photoBody = photo.calls[0].body as Record<string, any>;
  assert.match(
    photoBody.messages[1].content[0].text,
    /confidence to low.*visually mixed dishes.*Do not guess/,
  );

  const textAi = createAiProviders(
    environment({ OPENAI_API_KEY: "local-test-value", PLATEWISE_TEXT_MODEL: "fixture-model" }),
    recorder(lowConfidence).network,
  );
  const result = await textAi.analyzeText("uncertain mixed meal", "en");
  assert.equal(result.confidence, "low");
});

Deno.test("planned-dish portions and recipe adjustments stay within budget", async () => {
  const recommendation = {
    portion: "One small bowl",
    adjustments: ["Use less oil"],
    calorie_low: 300,
    calorie_high: 450,
    confidence: "medium",
    assumptions: ["Prepared with moderate oil"],
  };
  const { calls, network } = recorder(recommendation);
  const ai = createAiProviders(
    environment({ OPENAI_API_KEY: "local-test-value", PLATEWISE_TEXT_MODEL: "fixture-model" }),
    network,
  );
  const result = await ai.recommendDish("Vegetable curry", "en", 500);
  assert.equal(result.calorie_high, 450);
  const body = calls[0].body as Record<string, any>;
  assert.match(body.messages[0].content, /high estimate must be no greater than/);
  assert.deepEqual(JSON.parse(body.messages[1].content), {
    language: "en",
    dish: "Vegetable curry",
    budget: 500,
  });

  const overBudget = createAiProviders(
    environment({ OPENAI_API_KEY: "local-test-value", PLATEWISE_TEXT_MODEL: "fixture-model" }),
    recorder({ ...recommendation, calorie_high: 501 }).network,
  );
  await assert.rejects(
    overBudget.recommendDish("Vegetable curry", "en", 500),
    (error: ApiError) => error.code === "NO_FITTING_RECOMMENDATION",
  );

  const uncertain = createAiProviders(
    environment({ OPENAI_API_KEY: "local-test-value", PLATEWISE_TEXT_MODEL: "fixture-model" }),
    recorder({ ...recommendation, confidence: "low" }).network,
  );
  await assert.rejects(
    uncertain.recommendDish("Unclear curry", "en", 500),
    (error: ApiError) => error.code === "LOW_CONFIDENCE_RECOMMENDATION",
  );
});

Deno.test("json mode puts the schema in the prompt and still validates the reply", async () => {
  const { calls, network } = recorder({
    items: [{ ...food, calorie_low: 500 }],
    confidence: "low",
    assumptions: [],
    question: null,
  });
  const ai = createAiProviders(
    environment({
      PLATEWISE_AI_PROVIDER: "groq",
      GROQ_API_KEY: "k",
      PLATEWISE_STRUCTURED_OUTPUT: "json",
    }),
    network,
  );
  await assert.rejects(ai.analyzeText("Rice", "en"), /failed validation/);
  const body = calls[0].body as Record<string, any>;
  assert.deepEqual(body.response_format, { type: "json_object" });
  assert.match(body.messages[0].content, /JSON Schema/);
});

Deno.test("Groq speech goes to the transcription endpoint with the language", async () => {
  const { calls, network } = recorder();
  const ai = createAiProviders(
    environment({ PLATEWISE_AI_PROVIDER: "groq", GROQ_API_KEY: "k" }),
    network,
  );
  const text = await ai.transcribe(new File([new Uint8Array(30)], "meal.wav", { type: "audio/wav" }), "en");
  assert.equal(text, "one cup of rice");
  const [call] = calls;
  assert.equal(call.url, "https://api.groq.com/openai/v1/audio/transcriptions");
  const form = call.body as FormData;
  assert.equal(form.get("model"), "whisper-large-v3-turbo");
  assert.equal(form.get("language"), "en");
});

Deno.test("each capability can use a different provider", async () => {
  const { calls, network } = recorder();
  const ai = createAiProviders(
    environment({
      PLATEWISE_AI_PROVIDER: "groq",
      GROQ_API_KEY: "g",
      PLATEWISE_VISION_PROVIDER: "openai",
      OPENAI_API_KEY: "o",
    }),
    network,
  );
  assert.deepEqual(
    (["vision", "text", "speech"] as const).map((c) => ai.available(c)),
    [true, true, true],
  );
  assert.equal(ai.identity.kind, "openai+groq+groq");
  await ai.analyzePhoto({ bytes: new Uint8Array([1, 2, 3]), mime: "image/jpeg" });
  await ai.analyzeText("Rice", "en");
  assert.match(calls[0].url, /api\.openai\.com/);
  assert.match(calls[1].url, /api\.groq\.com/);
  const photo = calls[0].body as Record<string, any>;
  assert.equal(photo.messages[1].content[1].image_url.detail, "high");
});

Deno.test("Groq has no default vision model, so photos are unavailable until one is set", async () => {
  const ai = createAiProviders(
    environment({ PLATEWISE_AI_PROVIDER: "groq", GROQ_API_KEY: "g" }),
    recorder().network,
  );
  assert.equal(ai.available("vision"), false);
  assert.equal(ai.available("text"), true);
  await assert.rejects(ai.analyzePhoto({ bytes: new Uint8Array(3), mime: "image/png" }), /unavailable/);
  const withModel = createAiProviders(
    environment({
      PLATEWISE_AI_PROVIDER: "groq",
      GROQ_API_KEY: "g",
      PLATEWISE_VISION_MODEL: "some-vision-model",
    }),
    recorder().network,
  );
  assert.equal(withModel.available("vision"), true);
  const { calls, network } = recorder();
  const sent = createAiProviders(
    environment({
      PLATEWISE_AI_PROVIDER: "groq",
      GROQ_API_KEY: "g",
      PLATEWISE_VISION_MODEL: "some-vision-model",
    }),
    network,
  );
  await sent.analyzePhoto({ bytes: new Uint8Array([1]), mime: "image/png" });
  const body = calls[0].body as Record<string, any>;
  assert.equal(body.messages[1].content[1].image_url.detail, undefined);
  assert.match(body.messages[1].content[1].image_url.url, /^data:image\/png;base64,/);
});

Deno.test("nothing is available without a key, or with an unknown provider", async () => {
  for (
    const values of [{}, { PLATEWISE_AI_PROVIDER: "groq" }, {
      PLATEWISE_AI_PROVIDER: "nobody",
      OPENAI_API_KEY: "k",
    }]
  ) {
    const ai = createAiProviders(environment(values));
    assert.deepEqual((["vision", "text", "speech"] as const).map((c) => ai.available(c)), [
      false,
      false,
      false,
    ]);
    await assert.rejects(ai.analyzeText("Rice", "en"), /unavailable/);
  }
});

Deno.test("service failures become safe, retryable or final errors", async () => {
  const fail = (status: number): typeof fetch => () =>
    Promise.resolve(new Response("secret detail", { status }));
  const make = (network: typeof fetch) =>
    createAiProviders(environment({ OPENAI_API_KEY: "k" }), network, 50);
  await assert.rejects(
    make(fail(429)).analyzeText("Rice", "en"),
    (e: ApiError) => e.code === "AI_BUSY" && e.retryable,
  );
  await assert.rejects(
    make(fail(400)).analyzeText("Rice", "en"),
    (e: ApiError) => e.code === "AI_UNAVAILABLE" && !e.retryable,
  );
  const offline: typeof fetch = () => Promise.reject(new TypeError("down"));
  await assert.rejects(make(offline).analyzeText("Rice", "en"), (e: ApiError) => e.code === "AI_OFFLINE");
  const cut = make(() =>
    Promise.resolve(Response.json({ choices: [{ finish_reason: "length", message: { content: "{" } }] }))
  );
  await assert.rejects(cut.analyzeText("Rice", "en"), (e: ApiError) => e.code === "INVALID_ESTIMATE");
});

Deno.test("retry once for transient errors only", async () => {
  let count = 0;
  await assert.rejects(
    withRetry(() => Promise.reject(new ApiError("RETRY", String(++count), 503, true)), 0),
    /2/,
  );
  await assert.rejects(withRetry(() => Promise.reject(new ApiError("INVALID", String(++count))), 0), /3/);
});

Deno.test("Gemini asks in the prompt, sends no response format, store or token cap, and reads a fenced reply", async () => {
  const fence = "```";
  const { calls, network } = recorder(fence + "json\n" + JSON.stringify(meal) + "\n" + fence);
  const ai = createAiProviders(
    environment({ PLATEWISE_AI_PROVIDER: "gemini", GEMINI_API_KEY: "gemini-test-value" }),
    network,
  );
  const result = await ai.analyzeText("Rice and dal", "en");
  assert.equal(result.calorie_high, 241);
  const [call] = calls;
  const body = call.body as Record<string, any>;
  assert.equal(call.url, "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions");
  assert.equal(call.headers.get("Authorization"), "Bearer gemini-test-value");
  assert.equal(body.model, profiles.gemini.defaults.text);
  for (const field of ["response_format", "store", "max_completion_tokens", "tools"]) {
    assert.equal(field in body, false, field);
  }
  assert.match(body.messages[0].content, /JSON Schema/);
  assert.match(body.messages[0].content, /untrusted/);
});

Deno.test("Gemini photos use a data URI without an image detail field", async () => {
  const { calls, network } = recorder();
  const ai = createAiProviders(
    environment({ PLATEWISE_AI_PROVIDER: "gemini", GEMINI_API_KEY: "g" }),
    network,
  );
  assert.equal(ai.available("vision"), true);
  await ai.analyzePhoto({ bytes: new Uint8Array([1, 2]), mime: "image/jpeg" });
  const image = (calls[0].body as Record<string, any>).messages[1].content[1].image_url;
  assert.match(image.url, /^data:image\/jpeg;base64,/);
  assert.equal("detail" in image, false);
});

Deno.test("a loose menu reading is accepted and tidied rather than failing validation", async () => {
  const dishes = Array.from({ length: 25 }, (_, i) => ({ name: "Dish " + i }));
  const { network } = recorder({
    options: [
      { name: "Dal", printed_kcal: 320, calorie_evidence: "320 kcal" },
      { name: "Fish curry", portion: null, printed_kcal: 12.5, calorie_evidence: "12.5 kcal" },
      { name: "  ", portion: "1 cup" },
      ...dishes,
    ],
  });
  const ai = createAiProviders(
    environment({ PLATEWISE_AI_PROVIDER: "gemini", GEMINI_API_KEY: "g" }),
    network,
  );
  const { options } = await ai.extractMenu({ bytes: new Uint8Array([1, 2]), mime: "image/jpeg" });
  assert.equal(options.length, 18);
  assert.deepEqual(options[0], {
    name: "Dal",
    portion: null,
    printed_kcal: 320,
    calorie_evidence: "320 kcal",
  });
  assert.equal(options[1].printed_kcal, null);
  assert.equal(options[2].name, "Dish 0");
});

/** A network that answers Gemini's generateContent with [text], and records the request. */
function geminiSpeech(answer: unknown) {
  const calls: { url: string; headers: Headers; body: Record<string, any> }[] = [];
  const network: typeof fetch = (input, init) => {
    calls.push({
      url: String(input),
      headers: new Headers(init?.headers),
      body: JSON.parse(init?.body as string),
    });
    return Promise.resolve(Response.json(answer));
  };
  return { calls, network };
}
const heard = (text: string) => ({ candidates: [{ content: { parts: [{ text }] }, finishReason: "STOP" }] });
const gemini = { PLATEWISE_AI_PROVIDER: "gemini", GEMINI_API_KEY: "gemini-test-value" };
const wav = () => new File([new Uint8Array([82, 73, 70, 70])], "meal.wav", { type: "audio/wav" });

Deno.test("Gemini speech sends the recording to generateContent with the key in a header", async () => {
  const { calls, network } = geminiSpeech(heard(" one cup of rice \n"));
  const ai = createAiProviders(environment(gemini), network);
  assert.equal(ai.available("speech"), true);
  assert.equal(await ai.transcribe(wav(), "en"), "one cup of rice");
  const [call] = calls;
  assert.equal(
    call.url,
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
  );
  assert.equal(call.url.includes("gemini-test-value"), false);
  assert.equal(call.headers.get("x-goog-api-key"), "gemini-test-value");
  const parts = call.body.contents[0].parts;
  assert.match(parts[0].text, /word for word in English/);
  assert.match(parts[0].text, /untrusted/);
  assert.deepEqual(parts[1].inline_data, { mime_type: "audio/wav", data: btoa("RIFF") });
  assert.equal(call.body.generationConfig.temperature, 0);
});

Deno.test("Gemini speech names the language and maps the recording types the app makes", async () => {
  const { calls, network } = geminiSpeech(heard("ভাত"));
  const ai = createAiProviders(environment(gemini), network);
  await ai.transcribe(new File([new Uint8Array(30)], "meal.m4a", { type: "audio/mp4" }), "bn");
  await ai.transcribe(new File([new Uint8Array(30)], "meal.webm", { type: "audio/webm" }), "en");
  assert.match(calls[0].body.contents[0].parts[0].text, /Bangla/);
  assert.equal(calls[0].body.contents[0].parts[1].inline_data.mime_type, "audio/m4a");
  assert.equal(calls[1].body.contents[0].parts[1].inline_data.mime_type, "audio/webm");
});

Deno.test("Gemini speech joins the parts of a reply and treats silence or a block as unclear", async () => {
  const joined = createAiProviders(
    environment(gemini),
    geminiSpeech({ candidates: [{ content: { parts: [{ text: "rice " }, { text: "and dal" }] } }] }).network,
  );
  assert.equal(await joined.transcribe(wav(), "en"), "rice and dal");
  for (const answer of [{ candidates: [] }, heard(""), { promptFeedback: { blockReason: "SAFETY" } }]) {
    const ai = createAiProviders(environment(gemini), geminiSpeech(answer).network);
    await assert.rejects(ai.transcribe(wav(), "en"), (e: ApiError) => e.code === "UNCLEAR_AUDIO");
  }
});

Deno.test("Gemini speech failures are safe and an unknown recording type is refused", async () => {
  const status = (code: number): typeof fetch => () =>
    Promise.resolve(new Response("secret", { status: code }));
  const busy = createAiProviders(environment(gemini), status(429), 50);
  await assert.rejects(busy.transcribe(wav(), "en"), (e: ApiError) => e.code === "AI_BUSY" && e.retryable);
  const refused = createAiProviders(environment(gemini), status(400), 50);
  await assert.rejects(refused.transcribe(wav(), "en"), (e: ApiError) => e.code === "AI_UNAVAILABLE");
  const ai = createAiProviders(environment(gemini), geminiSpeech(heard("x")).network);
  await assert.rejects(
    ai.transcribe(new File([new Uint8Array(30)], "meal.mp3", { type: "audio/mpeg" }), "en"),
    (e: ApiError) => e.code === "AUDIO_TYPE",
  );
});

Deno.test("a slow Gemini recording fails once, quickly, with a clear timeout", async () => {
  let calls = 0;
  const hang: typeof fetch = (_input, init) => {
    calls++;
    return new Promise((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => reject(init.signal?.reason));
    });
  };
  const ai = createAiProviders(environment(gemini), hang, 60);
  const started = performance.now();
  await assert.rejects(ai.transcribe(wav(), "en"), (e: ApiError) => e.code === "AI_TIMEOUT");
  assert.equal(calls, 1);
  assert.ok(performance.now() - started < 400);
});

Deno.test("another provider can still take speech while Gemini does photos and text", async () => {
  const { calls, network } = recorder();
  const mixed = createAiProviders(
    environment({ ...gemini, PLATEWISE_SPEECH_PROVIDER: "groq", GROQ_API_KEY: "q" }),
    network,
  );
  assert.equal(mixed.identity.kind, "gemini+gemini+groq");
  await mixed.transcribe(new File([new Uint8Array(30)], "meal.wav", { type: "audio/wav" }), "en");
  assert.match(calls[0].url, /api\.groq\.com\/openai\/v1\/audio\/transcriptions/);
});

Deno.test("a model reply is read as JSON with or without decoration", () => {
  const fence = "```";
  assert.deepEqual(parseJsonReply('{"a":1}'), { a: 1 });
  assert.deepEqual(parseJsonReply(fence + 'json\n{"a":1}\n' + fence), { a: 1 });
  assert.deepEqual(parseJsonReply('Here you go: {"a":{"b":2}} Enjoy.'), { a: { b: 2 } });
  assert.throws(() => parseJsonReply("no json here"), SyntaxError);
});

Deno.test("the instructions ask for the requested language and keep the schema values", async () => {
  const { calls, network } = recorder();
  const ai = createAiProviders(environment({ OPENAI_API_KEY: "local-test-value" }), network);
  await ai.analyzeText("ভাত আর ডাল", "bn");
  const body = calls[0].body as Record<string, any>;
  assert.match(body.messages[0].content, /standard written Bangla/);
  assert.match(body.messages[0].content, /enum values such as units/);
  assert.match(body.messages[1].content, /"language":"bn"/);
});
