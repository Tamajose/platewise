import assert from "node:assert/strict";
import { createSmsHandler } from "./sms_handler.ts";

const token = "test-token";
const services = { token: () => token, appId: () => "APP_000001" };

const post = (body: unknown, query = `?token=${token}`) =>
  new Request(`https://example.test/functions/v1/sms-receive${query}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

Deno.test("an MO message is acknowledged", async () => {
  const response = await createSmsHandler(services)(
    post({ applicationId: "APP_000001", requestId: "r1", message: "STOP" }),
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { statusCode: "S1000", statusDetail: "Success" });
});

Deno.test("a malformed body is still acknowledged", async () => {
  const response = await createSmsHandler(services)(post("not json"));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { statusCode: "S1000", statusDetail: "Success" });
});

Deno.test("a message for another application is acknowledged without acting", async () => {
  const response = await createSmsHandler(services)(
    post({ applicationId: "APP_999999", requestId: "r2", message: "STOP" }),
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { statusCode: "S1000", statusDetail: "Success" });
});

Deno.test("a wrong token is refused", async () => {
  const response = await createSmsHandler(services)(post({}, "?token=wrong"));
  assert.equal(response.status, 401);
});

Deno.test("an unconfigured endpoint is unavailable", async () => {
  const response = await createSmsHandler({ token: () => undefined })(post({}));
  assert.equal(response.status, 503);
});

Deno.test("a non-POST request is refused", async () => {
  const request = new Request(`https://example.test/functions/v1/sms-receive?token=${token}`);
  const response = await createSmsHandler(services)(request);
  assert.equal(response.status, 405);
});
