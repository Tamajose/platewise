import type { z } from "zod";
import type { estimate, item } from "./contracts.ts";
import type { MenuExtraction } from "./menu.ts";

/**
 * The interfaces the application needs from the AI services. Domain code and
 * the application depend on these, never on a vendor, so a vendor can change
 * without touching either.
 */

export type MealEstimate = Omit<ReturnType<typeof estimate>, "items"> & { items: z.infer<typeof item>[] };
export type ImageInput = { bytes: Uint8Array; mime: string };
export type Language = "en" | "bn";

export interface MealVisionProvider {
  analyzePhoto(image: ImageInput): Promise<MealEstimate>;
}
export type DishRecommendation = {
  portion: string;
  adjustments: string[];
  calorie_low: number;
  calorie_high: number;
  confidence: "low" | "medium" | "high";
  assumptions: string[];
};
export interface TextNutritionProvider {
  analyzeText(text: string, language: Language): Promise<MealEstimate>;
  recommendDish(text: string, language: Language, budget: number): Promise<DishRecommendation>;
}
export interface SpeechToTextProvider {
  transcribe(audio: File, language: Language): Promise<string>;
}
export interface MenuExtractionProvider {
  extractMenu(image: ImageInput): Promise<MenuExtraction>;
}
export interface ExplanationProvider {
  chooseFacts(facts: readonly string[]): Promise<readonly number[]>;
}

/** What an AI call needs, so unavailable pieces can be reported separately. */
export type Capability = "vision" | "text" | "speech";

export interface AiProviders
  extends
    MealVisionProvider,
    TextNutritionProvider,
    SpeechToTextProvider,
    MenuExtractionProvider,
    ExplanationProvider {
  /** Whether [capability] is configured, with a key and a model. */
  available(capability: Capability): boolean;
  /**
   * Names the configured providers and models. Part of the cache key, so a
   * cached estimate is never served after the provider or model changes.
   */
  readonly identity: { readonly kind: string; readonly vision: string; readonly text: string };
}

/** Switches that are on only after the language has been tested. */
export interface Flags {
  readonly banglaText: boolean;
  readonly banglaSpeech: boolean;
}

/** Phone verification through a carrier OTP service. */
export interface PhoneProvider {
  /** Whether the application credentials are configured. */
  available(): boolean;
  /** Sends an OTP to a tel: address. The reference stays server-side. */
  requestOtp(subscriberId: string): Promise<{ referenceNo: string }>;
  /** Verifies the code; the platform activates the subscription on success. */
  verifyOtp(
    referenceNo: string,
    otp: string,
  ): Promise<{ subscriberId: string; subscriptionStatus: string }>;
}

/** What the application receives from the composition root. */
export interface Services {
  readonly ai: AiProviders;
  readonly flags: Flags;
  readonly phone: PhoneProvider;
}

/** Menu rows from a seeded dataset of fictional venues. */
export type Restaurant = {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  source: string;
  attribution: string;
  dataset: "seeded";
  last_verified_at: string | null;
};
export type MenuRow = {
  id: string;
  name: string;
  portion: string;
  calorie_low: number;
  calorie_high: number;
  protein_g: number | null;
  carbohydrate_g: number | null;
  fat_g: number | null;
  fiber_g: number | null;
  sodium_mg: number | null;
  restaurant: Restaurant;
};
export interface NearbyMenuProvider {
  getMenus(): Promise<MenuRow[]>;
}
