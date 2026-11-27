import assert from "node:assert/strict";
import { isOptOut, parseSmsMessage } from "./sms_message.ts";

Deno.test("an MO message is read from the callback body", () => {
  assert.deepEqual(
    parseSmsMessage({
      version: "1.0",
      applicationId: "APP_000001",
      sourceAddress: "tel:8801959979376",
      message: "platewise STOP",
      requestId: "r1",
      encoding: "0",
    }),
    {
      applicationId: "APP_000001",
      sourceAddress: "tel:8801959979376",
      message: "platewise STOP",
      requestId: "r1",
      encoding: "0",
    },
  );
});

Deno.test("a body without a mandatory field is not an MO message", () => {
  assert.equal(parseSmsMessage({ applicationId: "APP_000001" }), null);
  assert.equal(parseSmsMessage("not an object"), null);
});

Deno.test("STOP, UNSUB and OFF are recognised with or without the keyword", () => {
  for (
    const message of ["STOP", "stop", "platewise STOP", "platewise stop.", "PlateWise Unsub", "platewise OFF"]
  ) {
    assert.equal(isOptOut(message), true, message);
  }
  for (const message of ["platewise JOIN", "STOPPED", "please do not stop the service", "platewise HELP"]) {
    assert.equal(isOptOut(message), false, message);
  }
});
