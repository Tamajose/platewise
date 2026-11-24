import type { z } from "zod";
import { type nearbyInput, rankNearby } from "../domain/decision.ts";
import type { NearbyMenuProvider } from "../domain/ports.ts";
import { SeededMenuProvider } from "../infra/menus.ts";
import type { Session } from "../infra/supabase.ts";

/** Meals from seeded venues around a point, ranked for a budget. */
export async function nearby(
  session: Session,
  p: z.infer<typeof nearbyInput>,
  adapter: NearbyMenuProvider = new SeededMenuProvider(session.client),
) {
  return rankNearby(await adapter.getMenus(), p);
}
