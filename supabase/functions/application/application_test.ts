import assert from "node:assert/strict";
import { minPlannableBudget } from "../domain/contracts.ts";
import { compareInput } from "../domain/decision.ts";
import type { Services } from "../domain/ports.ts";
import type { Session } from "../infra/supabase.ts";
import { compare } from "./compare.ts";
import { nearby } from "./nearby.ts";
import { erase } from "./privacy.ts";
import { run } from "./actions.ts";
import { createPhoneProvider } from "../providers/applink.ts";
import { createAiProviders } from "../providers/registry.ts";

/** Services with no AI configured, which printed-calorie options never need. */
const services: Services = {
  ai: createAiProviders(() => undefined),
  flags: { banglaText: false, banglaSpeech: false },
  phone: createPhoneProvider(() => undefined),
};
const range = (calorie_low: number, calorie_high: number) => ({ calorie_low, calorie_high });

Deno.test("two and three options, stable ties and per-option ownership failure", async () => {
  const m = {
    kind: "menu",
    key: "0",
    name: "Rice and dal",
    portion: "1 bowl",
    printed_kcal: 500,
    language: "en",
  };
  const x = {
    kind: "photo",
    key: "2",
    image_storage_path: "22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.jpg",
  };
  const session = { uid: "11111111-1111-4111-8111-111111111111" } as Session;
  const p = compareInput.parse({ budget: 600, options: [m, { ...m, key: "1" }, x] });
  const result = await compare(session, p, services);
  assert.deepEqual(result.results.map((r) => r.key), ["0", "1"]);
  assert.equal(result.failures[0].code, "NOT_FOUND");
  assert.equal(compareInput.safeParse({ budget: 600, options: [m, m] }).success, false);
  assert.equal(
    (await compare(session, compareInput.parse({ budget: 600, options: [m, { ...m, key: "1" }] }), services))
      .results.length,
    2,
  );
});
Deno.test("a dish that needs the AI reports why when the AI is not configured", async () => {
  const dish = (key: string) => ({
    kind: "menu",
    key,
    name: "Rice",
    portion: null,
    printed_kcal: null,
    language: "en",
  });
  const p = compareInput.parse({ budget: null, options: [dish("0"), dish("1")] });
  const cache = {
    select: () => ({
      eq: () => ({ eq: () => ({ gt: () => ({ maybeSingle: () => ({ data: null, error: null }) }) }) }),
    }),
  };
  const session = { uid: "u", admin: { from: () => cache } } as unknown as Session;
  const result = await compare(session, p, services);
  assert.equal(result.results.length, 0);
  assert.deepEqual(result.failures.map((f) => f.code), ["AI_UNAVAILABLE", "AI_UNAVAILABLE"]);
});
Deno.test("planned-dish recommendations require a configured text provider", async () => {
  const input = {
    dish: "Vegetable curry",
    language: "en",
    budget: 500,
  } as const;
  const cache = {
    select: () => ({
      eq: () => ({ eq: () => ({ gt: () => ({ maybeSingle: () => ({ data: null, error: null }) }) }) }),
    }),
  };
  const session = {
    uid: "u",
    client: { from: () => ({ select: () => ({ maybeSingle: () => ({ data: null, error: null }) }) }) },
    admin: { from: () => cache },
  } as unknown as Session;
  await assert.rejects(
    run(session, "recommend_dish", input, services),
    (error: Error & { code?: string }) => error.code === "AI_UNAVAILABLE",
  );
});
Deno.test("a budget too small for a portion is refused before any AI call", async () => {
  const session = {
    uid: "u",
    client: { from: () => ({ select: () => ({ maybeSingle: () => ({ data: null, error: null }) }) }) },
  } as unknown as Session;
  for (const budget of [1, 30, minPlannableBudget - 1]) {
    await assert.rejects(
      run(session, "recommend_dish", { dish: "Vegetable curry", language: "en", budget }, services),
      (error: Error & { code?: string; status?: number }) =>
        error.code === "BUDGET_TOO_SMALL" && error.status === 422 && !/skip|fast|starve/i.test(error.message),
    );
  }
});
Deno.test("the smallest plannable budget is passed on to the AI", async () => {
  const cache = {
    select: () => ({
      eq: () => ({ eq: () => ({ gt: () => ({ maybeSingle: () => ({ data: null, error: null }) }) }) }),
    }),
  };
  const session = {
    uid: "u",
    client: { from: () => ({ select: () => ({ maybeSingle: () => ({ data: null, error: null }) }) }) },
    admin: { from: () => cache },
  } as unknown as Session;
  await assert.rejects(
    run(
      session,
      "recommend_dish",
      { dish: "Vegetable curry", language: "en", budget: minPlannableBudget },
      services,
    ),
    (error: Error & { code?: string }) => error.code === "AI_UNAVAILABLE",
  );
});
Deno.test("Bangla menu text needs the language switch", async () => {
  const p = compareInput.parse({
    budget: null,
    options: [
      { kind: "menu", key: "0", name: "ভাত", portion: null, printed_kcal: null, language: "bn" },
      { kind: "menu", key: "1", name: "ডাল", portion: null, printed_kcal: null, language: "bn" },
    ],
  });
  const result = await compare({ uid: "u" } as Session, p, services);
  assert.deepEqual(result.failures.map((f) => f.code), ["LANGUAGE_UNAVAILABLE", "LANGUAGE_UNAVAILABLE"]);
});
Deno.test("nearby asks its menu source and ranks the result", async () => {
  const venue = {
    id: "v",
    name: "Sample",
    latitude: 23,
    longitude: 91,
    source: "fixture",
    attribution: "PlateWise",
    dataset: "seeded" as const,
    last_verified_at: null,
  };
  const row = {
    id: "b",
    name: "Rice and dal",
    portion: "Bowl",
    ...range(400, 500),
    protein_g: null,
    carbohydrate_g: null,
    fat_g: null,
    fiber_g: null,
    sodium_mg: null,
    restaurant: venue,
  };
  const found = await nearby({} as Session, { latitude: 23, longitude: 91, radius_km: 2, budget: 650 }, {
    getMenus: () => Promise.resolve([row, { ...row, id: "a" }]),
  });
  assert.deepEqual(found.options.map((v) => v.id), ["a", "b"]);
});
Deno.test("storage failure keeps deletion pending and blocks touching auth", async () => {
  const calls: string[] = [];
  let failStorage = true;
  let exists = true;
  const session = {
    uid: "owner",
    admin: {
      rpc(name: string) {
        calls.push(name);
        return Promise.resolve({ data: { delete_account: true }, error: null });
      },
      storage: {
        from() {
          return {
            list() {
              return Promise.resolve({ data: exists ? [{ name: "sample.jpg" }] : [], error: null });
            },
            remove(paths: string[]) {
              assert.deepEqual(paths, ["owner/sample.jpg"]);
              if (failStorage) return Promise.resolve({ error: { message: "private error" } });
              exists = false;
              return Promise.resolve({ error: null });
            },
          };
        },
      },
      auth: {
        admin: {
          deleteUser(id: string, soft: boolean) {
            assert.equal(id, "owner");
            assert.equal(soft, false);
            calls.push("remove_identity");
            return Promise.resolve({ error: null });
          },
        },
      },
    },
  } as unknown as Session;
  await assert.rejects(erase(session, true), /pending/);
  assert.deepEqual(calls, ["pw_delete_begin"]);
  failStorage = false;
  assert.deepEqual(await erase(session, true), { deleted: true, account_deleted: true });
  assert.deepEqual(calls, ["pw_delete_begin", "pw_delete_begin", "pw_delete_finalize", "remove_identity"]);
});

Deno.test("an export asks the database for the chosen number of days", async () => {
  const calls: unknown[] = [];
  const client = {
    rpc: (name: string, args: unknown) => {
      calls.push([name, args]);
      return Promise.resolve({ data: { days: 30 }, error: null });
    },
    from: () => ({ select: () => ({ maybeSingle: () => Promise.resolve({ data: null, error: null }) }) }),
  };
  const session = { uid: "u", client, admin: client } as unknown as Session;
  assert.deepEqual(await run(session, "export_stats", { days: 30 }, services), { days: 30 });
  assert.deepEqual(calls, [["pw_export", { p_days: 30 }]]);
});

Deno.test("an export is limited to one week up to one year", async () => {
  const { actions } = await import("./actions.ts");
  for (const days of [6, 366, 7.5, "30"]) {
    assert.equal(actions.export_stats.safeParse({ days }).success, false, String(days));
  }
  for (const days of [7, 30, 365]) {
    assert.equal(actions.export_stats.safeParse({ days }).success, true, String(days));
  }
});
