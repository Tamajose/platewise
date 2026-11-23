import { z } from "zod";
import { estimateMetrics } from "./metrics.ts";

const observation = z.strictObject({
  calorie_low: z.number().int().nonnegative(),
  calorie_high: z.number().int().nonnegative(),
  representative_calories: z.number().int().nonnegative(),
});
type Fixture = {
  id: string;
  description: string;
  language?: string;
  components?: { grams: number; kcal_per_100g: number }[];
};
const data = JSON.parse(
  await Deno.readTextFile(new URL("../testdata/local-meals.json", import.meta.url)),
) as {
  reference_cases: Fixture[];
  illustrative_cases: Fixture[];
};
const url = Deno.env.get("PLATEWISE_EVAL_URL");
const key = Deno.env.get("PLATEWISE_EVAL_PUBLISHABLE_KEY");
const token = Deno.env.get("PLATEWISE_EVAL_ACCESS_TOKEN");
const live = Deno.env.get("PLATEWISE_EVAL_LIVE") === "1";
if (!live) {
  console.log(JSON.stringify(
    {
      state: "fixtures_ready",
      reference_cases: data.reference_cases.length,
      illustrative_cases: data.illustrative_cases.length,
      test_method:
        "Text HTTP request start through parsed response. Ready for externally authorized live verification.",
      provider_requests: 0,
    },
    null,
    2,
  ));
  Deno.exit(0);
}
if (!url?.startsWith("https://") || !key || !token) {
  throw new Error(
    "Set the HTTPS URL, publishable key and short-lived test access token through environment variables.",
  );
}

const rows = [];
// Six reference cases fit within the default per-user quota. Illustrated cases have no truth values.
for (const example of data.reference_cases) {
  const started = performance.now();
  const expected = example.components!.reduce((sum, item) => sum + item.grams * item.kcal_per_100g / 100, 0);
  let result = null;
  let error = null;
  try {
    const response = await fetch(new URL("/functions/v1/platewise", url), {
      method: "POST",
      headers: { "content-type": "application/json", apikey: key, authorization: "Bearer " + token },
      body: JSON.stringify({
        version: 1,
        action: "analyze_text",
        input: { description: example.description, language: example.language ?? "en" },
      }),
      signal: AbortSignal.timeout(24000),
    });
    const body = await response.json();
    if (!body.ok) error = typeof body.error?.code === "string" ? body.error.code : "REQUEST_FAILED";
    else {
      const parsed = observation.safeParse(
        Object.fromEntries(Object.keys(observation.shape).map((name) => [name, body.data[name]])),
      );
      if (parsed.success) result = parsed.data;
      else error = "INVALID_RESPONSE";
    }
  } catch {
    error = "TRANSPORT";
  }
  rows.push({ id: example.id, expected, result, error, elapsedMs: performance.now() - started });
}
console.log(JSON.stringify({ state: "live", rows, metrics: estimateMetrics(rows) }, null, 2));
