import assert from "node:assert/strict";

/**
 * Keeps the backend layered. Each layer may import only the layers beneath it:
 *
 *   platewise (HTTP handler)  may import every layer
 *   application               may import domain and infra
 *   infra                     may import domain
 *   providers                 may import domain
 *   domain                    imports nothing of ours, and no I/O
 *
 * Tests are exempt, because they build layers together. The rules are pure
 * functions, so the second half of this file shows that they catch breaches.
 */

type Layer = "domain" | "application" | "infra" | "providers" | "platewise";

const allowedLayers: Record<Layer, readonly Layer[]> = {
  domain: ["domain"],
  infra: ["infra", "domain"],
  providers: ["providers", "domain"],
  application: ["application", "infra", "domain"],
  platewise: ["platewise", "application", "infra", "providers", "domain"],
};

/** Packages a layer may import. Everything else needs a decision here first. */
const allowedPackages: Record<Layer, readonly string[]> = {
  domain: ["zod"],
  infra: ["zod", "@supabase/supabase-js"],
  providers: ["zod"],
  application: ["zod"],
  platewise: ["zod", "@supabase/supabase-js"],
};

/** Words that mean a file does input or output. Only some layers may use them. */
const ioWords: { layers: readonly Layer[]; pattern: RegExp; reason: string }[] = [
  { layers: ["domain"], pattern: /\bDeno\./, reason: "domain code must not use the Deno runtime" },
  { layers: ["domain"], pattern: /\bfetch\b/, reason: "domain code must not use the network" },
  {
    layers: ["application", "providers"],
    pattern: /\bDeno\./,
    reason: "only infra reads the runtime and environment",
  },
  {
    layers: ["domain", "application"],
    pattern: /\b(?:client|admin)\.from\(|\.rpc\(|\.storage\b|createClient/,
    reason: "database and storage access belongs to infra",
  },
];

export function layerOf(path: string): Layer | null {
  const first = path.replaceAll("\\", "/").split("/").find((part) => part in allowedLayers);
  return (first as Layer | undefined) ?? null;
}

const importPatterns = [
  /^\s*(?:import|export)\b[^;"']*?\bfrom\s*["']([^"']+)["']/gm,
  /^\s*import\s*["']([^"']+)["']/gm,
];

export function importsIn(source: string): string[] {
  return importPatterns.flatMap((pattern) => [...source.matchAll(pattern)].map((m) => m[1]));
}

/** Describes every rule that [source], found at [path], breaks. */
export function violations(path: string, source: string): string[] {
  const layer = layerOf(path);
  if (layer === null || path.endsWith("_test.ts")) return [];
  const problems: string[] = [];
  for (const spec of importsIn(source)) {
    if (spec.startsWith(".")) {
      const target = layerOf(new URL(spec, "file:///" + path.replaceAll("\\", "/")).pathname);
      if (target !== null && !allowedLayers[layer].includes(target)) {
        problems.push(`${path}: ${layer} must not import ${target} (${spec})`);
      }
    } else {
      const name = spec.replace(/^npm:/, "").replace(/^(@[^/]+\/[^/@]+|[^/@]+).*$/, "$1");
      if (spec.startsWith("npm:") || spec.startsWith("jsr:") || spec.startsWith("https:")) {
        problems.push(`${path}: import packages by name through deno.json, not ${spec}`);
      } else if (!spec.startsWith("node:") && !allowedPackages[layer].includes(name)) {
        problems.push(`${path}: ${layer} must not import the package ${name}`);
      }
    }
  }
  const code = source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:])\/\/.*$/gm, "$1");
  for (const rule of ioWords) {
    if (rule.layers.includes(layer) && rule.pattern.test(code)) problems.push(`${path}: ${rule.reason}`);
  }
  return problems;
}

async function* sources(dir: URL): AsyncGenerator<{ path: string; source: string }> {
  for await (const entry of Deno.readDir(dir)) {
    const child = new URL(entry.name + (entry.isDirectory ? "/" : ""), dir);
    if (entry.isDirectory) yield* sources(child);
    else if (entry.name.endsWith(".ts")) {
      yield { path: child.pathname.split("/functions/")[1], source: await Deno.readTextFile(child) };
    }
  }
}

Deno.test("every backend file respects the layers", async () => {
  const found: string[] = [];
  let checked = 0;
  for await (const file of sources(new URL("./", import.meta.url))) {
    if (layerOf(file.path) === null) continue;
    checked++;
    found.push(...violations(file.path, file.source));
  }
  assert.ok(checked > 20, `only ${checked} files were checked`);
  assert.deepEqual(found, []);
});

Deno.test("the checks catch a layer breach", () => {
  const cases: [string, string, RegExp][] = [
    ["domain/x.ts", 'import { env } from "../infra/config.ts";', /domain must not import infra/],
    [
      "infra/x.ts",
      'import { createAiProviders } from "../providers/registry.ts";',
      /infra must not import providers/,
    ],
    ["providers/x.ts", 'import { rpc } from "../infra/supabase.ts";', /providers must not import infra/],
    [
      "application/x.ts",
      'import { createAiProviders } from "../providers/registry.ts";',
      /application must not import providers/,
    ],
    [
      "application/x.ts",
      'import { handler } from "../platewise/handler.ts";',
      /application must not import platewise/,
    ],
    ["domain/x.ts", 'import { createClient } from "@supabase/supabase-js";', /must not import the package/],
    ["providers/x.ts", 'import { z } from "npm:zod@4";', /through deno.json/],
    ["domain/x.ts", "const key = Deno.env.get('A');", /must not use the Deno runtime/],
    ["domain/x.ts", "await fetch('https://x');", /must not use the network/],
    ["application/x.ts", "const v = Deno.env.get('A');", /only infra reads/],
    ["application/x.ts", "await client.rpc('x');", /belongs to infra/],
  ];
  for (const [path, source, expected] of cases) {
    assert.match(violations(path, source).join("\n"), expected, `${path}: ${source}`);
  }
});

Deno.test("allowed imports, comments and tests are not flagged", () => {
  assert.deepEqual(
    violations("application/x.ts", 'import { rpc } from "../infra/supabase.ts";\nimport { z } from "zod";'),
    [],
  );
  assert.deepEqual(
    violations("platewise/x.ts", 'import { createAiProviders } from "../providers/registry.ts";'),
    [],
  );
  assert.deepEqual(violations("domain/x.ts", "// Deno.env is not used here\n/* fetch */ const a = 1;"), []);
  assert.deepEqual(violations("domain/x_test.ts", 'import { handler } from "../platewise/handler.ts";'), []);
  assert.deepEqual(violations("providers/x.ts", 'import assert from "node:assert";'), []);
});
