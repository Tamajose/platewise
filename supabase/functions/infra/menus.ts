import type { SupabaseClient } from "@supabase/supabase-js";
import type { MenuRow, NearbyMenuProvider } from "../domain/ports.ts";
import { dataError } from "./supabase.ts";

/** Menus of the fictional venues in the seeded dataset, read under the caller's own access. */
export class SeededMenuProvider implements NearbyMenuProvider {
  constructor(private readonly client: SupabaseClient) {}

  async getMenus(): Promise<MenuRow[]> {
    const { data, error } = await this.client.from("menu_items").select(
      "id,name,portion,calorie_low,calorie_high,protein_g,carbohydrate_g,fat_g,fiber_g,sodium_mg,restaurant:restaurants!inner(id,name,latitude,longitude,source,attribution,dataset,last_verified_at)",
    ).eq("restaurant.dataset", "seeded").order("id").limit(150);
    if (error) dataError(error);
    return (data ?? []) as unknown as MenuRow[];
  }
}
