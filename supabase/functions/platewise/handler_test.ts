import assert from "node:assert/strict";
import { createHandler, createServices, handler } from "./handler.ts";

Deno.test("edge refuses missing session with a request ID", async () => {
  const response = await handler(new Request("https://backend.example/platewise", { method: "POST" }));
  assert.equal(response.status, 401);
  const data = await response.json();
  assert.equal(data.error.code, "SESSION_REQUIRED");
  assert.ok(data.request_id);
  assert.equal(response.headers.get("X-Request-ID"), data.request_id);
});

Deno.test("only POST and preflight are accepted", async () => {
  const get = await handler(new Request("https://backend.example/platewise", { method: "GET" }));
  assert.equal(get.status, 405);
  const preflight = await handler(new Request("https://backend.example/platewise", { method: "OPTIONS" }));
  assert.equal(preflight.status, 204);
});

Deno.test("cleanup needs its secret", async () => {
  const response = await handler(
    new Request("https://backend.example/platewise", {
      method: "POST",
      headers: { "x-platewise-cleanup": "nope" },
    }),
  );
  assert.equal(response.status, 401);
});

Deno.test("services are built from the environment passed in", () => {
  const services = createServices((name) => ({ PLATEWISE_BANGLA_TEXT_ENABLED: "true" })[name]);
  assert.equal(services.flags.banglaText, true);
  assert.equal(services.flags.banglaSpeech, false);
  assert.equal(services.ai.available("text"), false);
  assert.equal(typeof createHandler(services), "function");
});
