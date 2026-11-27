import type { SupabaseClient } from "@supabase/supabase-js";
import type { SubscriptionEvent } from "../domain/subscription_event.ts";

/** Stores one subscription message. Only the server's own client may do this. */
export async function saveSubscriptionEvent(admin: SupabaseClient, event: SubscriptionEvent) {
  // The same change can be delivered more than once, so a repeat is ignored.
  const { error } = await admin.from("subscription_events").upsert(event, {
    onConflict: "subscriber,status,event_time",
    ignoreDuplicates: true,
  });
  // Only the error code is kept: the message can quote the row, which holds a phone number.
  if (error) throw new Error("subscription event was not stored (" + (error.code ?? "no code") + ")");
}
