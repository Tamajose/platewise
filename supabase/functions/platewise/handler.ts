import { envelope, fail } from "../domain/contracts.ts";
import type { Services } from "../domain/ports.ts";
import { type ActionName, actions, audioRequest, cleanup, run } from "../application/actions.ts";
import { assertAvailable } from "../application/privacy.ts";
import { env, readFlags } from "../infra/config.ts";
import { authenticate } from "../infra/supabase.ts";
import { cors, readLimited, response } from "../infra/web.ts";
import { createAiProviders } from "../providers/registry.ts";

/** Builds the services the application uses from the environment. */
export function createServices(get: (name: string) => string | undefined = env): Services {
  return { ai: createAiProviders(get), flags: readFlags(get) };
}

/**
 * The HTTP entry point: checks the request, signs the caller in, validates the
 * action's input and hands over to the application. It holds no business rules.
 */
export function createHandler(services: Services) {
  return async (request: Request) => {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(request) });
    const id = crypto.randomUUID();
    try {
      if (request.method !== "POST") fail("METHOD", "Use POST for this request.", 405);
      if (request.headers.has("x-platewise-cleanup")) return response(request, id, await cleanup(request));
      const session = await authenticate(request);
      const contentType = request.headers.get("Content-Type")?.toLowerCase() ?? "";
      if (contentType.startsWith("multipart/form-data;")) {
        await assertAvailable(session);
        return response(request, id, await audioRequest(session, request, services));
      }
      if (!contentType.startsWith("application/json")) {
        fail("CONTENT_TYPE", "This request requires JSON.", 415);
      }
      let json: unknown;
      try {
        json = JSON.parse(new TextDecoder().decode(await readLimited(request, 48 * 1024)));
      } catch (error) {
        if (error instanceof SyntaxError) fail("VALIDATION", "This JSON request could not be read.");
        throw error;
      }
      const parsed = envelope.safeParse(json);
      if (!parsed.success) return fail("VALIDATION", "Check the version and input of this request.");
      const action = parsed.data.action as ActionName;
      if (!Object.hasOwn(actions, action)) return fail("UNKNOWN_ACTION", "This action is unavailable.", 404);
      const input = actions[action].safeParse(parsed.data.input);
      if (!input.success) return fail("VALIDATION", "Check the values and try again.");
      return response(request, id, await run(session, action, input.data, services));
    } catch (error) {
      return response(request, id, null, error);
    }
  };
}

export const handler = createHandler(createServices());
