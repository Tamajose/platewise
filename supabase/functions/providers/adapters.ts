import { z } from "zod";
import {
  ApiError,
  dishRecommendationOutput,
  estimate,
  fail,
  modelEstimate,
  redact,
} from "../domain/contracts.ts";
import { menuOutput, normalizeMenu } from "../domain/menu.ts";
import type {
  ExplanationProvider,
  ImageInput,
  Language,
  MealVisionProvider,
  MenuExtractionProvider,
  SpeechToTextProvider,
  TextNutritionProvider,
} from "../domain/ports.ts";
import type { ChatClient } from "./chat_client.ts";
import { dishRecommendationPolicy, factsPolicy, menuPolicy, nutritionPolicy } from "./prompts.ts";
import type { TranscriptionClient } from "./gemini_speech.ts";

const factsOutput = z.strictObject({ indices: z.array(z.number().int().min(0).max(15)).min(1).max(3) });

/** Reads meals and menus from pictures. */
export class VisionAdapter implements MealVisionProvider, MenuExtractionProvider {
  constructor(private readonly client: ChatClient, readonly model: string) {}

  async analyzePhoto(image: ImageInput) {
    const value = await this.client.structured(
      this.model,
      "food_photo",
      nutritionPolicy,
      this.client.imageContent(
        image.bytes,
        image.mime,
        "Estimate the visible meal and typical preparation. Set confidence to low when the dish identity, ingredients, or portion cannot be identified confidently, especially for visually mixed dishes. Do not guess unsupported ingredients or portions.",
      ),
      modelEstimate,
    );
    if (value.confidence === "low") {
      fail(
        "LOW_CONFIDENCE_PHOTO",
        "I’m not confident enough to estimate this meal from the photo. Try a clearer photo or describe the dishes and portions, or enter the meal manually. If you need nutrition guidance for a health decision, consult a qualified healthcare professional.",
        422,
      );
    }
    return estimate(value, this.model);
  }

  async extractMenu(image: ImageInput) {
    return normalizeMenu(
      await this.client.structured(
        this.model,
        "menu_options",
        menuPolicy,
        this.client.imageContent(image.bytes, image.mime, "Read the visible menu only."),
        menuOutput,
      ),
    );
  }
}

/** Estimates meals from descriptions and chooses facts for the weekly summary. */
export class TextAdapter implements TextNutritionProvider, ExplanationProvider {
  constructor(private readonly client: ChatClient, readonly model: string) {}

  async analyzeText(text: string, language: Language) {
    const value = await this.client.structured(
      this.model,
      "food_text",
      nutritionPolicy,
      JSON.stringify({ language, description: redact(text) }),
      modelEstimate,
    );
    return estimate(value, this.model);
  }

  async recommendDish(text: string, language: Language, budget: number) {
    const value = dishRecommendationOutput.parse(
      await this.client.structured(
        this.model,
        "dish_recommendation",
        dishRecommendationPolicy,
        JSON.stringify({ language, dish: redact(text), budget }),
        dishRecommendationOutput,
      ),
    );
    if (value.calorie_high > budget) {
      fail(
        "NO_FITTING_RECOMMENDATION",
        "I couldn’t find a plausible portion and recipe adjustment within that budget. Try a different dish or increase the meal budget.",
        422,
      );
    }
    if (value.confidence === "low") {
      fail(
        "LOW_CONFIDENCE_RECOMMENDATION",
        "I’m not confident enough to suggest a portion for this dish. Add preparation details or try another dish.",
        422,
      );
    }
    return {
      ...value,
      portion: redact(value.portion).slice(0, 160),
      adjustments: value.adjustments.map((entry) => redact(entry).slice(0, 160)),
      assumptions: value.assumptions.map((entry) => redact(entry).slice(0, 200)),
    };
  }

  async chooseFacts(facts: readonly string[]) {
    const response = await this.client.structured(
      this.model,
      "summary_selection",
      factsPolicy,
      JSON.stringify(facts),
      factsOutput,
    );
    return [...new Set(response.indices)].filter((index) => index < facts.length);
  }
}

/** Turns a short recording into text. */
export class SpeechAdapter implements SpeechToTextProvider {
  constructor(private readonly client: TranscriptionClient, readonly model: string) {}

  async transcribe(audio: File, language: Language) {
    const text = await this.client.transcribe(this.model, audio, language);
    const result = z.string().trim().min(2).max(1200).safeParse(text);
    if (!result.success) {
      return fail("UNCLEAR_AUDIO", "The recording could not be understood. Try again or type the meal.", 422);
    }
    return redact(result.data);
  }
}

/** Stands in for a capability that is not configured. Every call says so. */
export class UnavailableAdapter
  implements
    MealVisionProvider,
    MenuExtractionProvider,
    TextNutritionProvider,
    ExplanationProvider,
    SpeechToTextProvider {
  private unavailable(): Promise<never> {
    return Promise.reject(
      new ApiError(
        "AI_UNAVAILABLE",
        "Live analysis is unavailable here. You can enter the meal manually.",
        503,
      ),
    );
  }
  analyzePhoto(_image: ImageInput): Promise<never> {
    return this.unavailable();
  }
  extractMenu(_image: ImageInput): Promise<never> {
    return this.unavailable();
  }
  analyzeText(_text: string, _language: Language): Promise<never> {
    return this.unavailable();
  }
  recommendDish(_text: string, _language: Language, _budget: number): Promise<never> {
    return this.unavailable();
  }
  chooseFacts(_facts: readonly string[]): Promise<never> {
    return this.unavailable();
  }
  transcribe(_audio: File, _language: Language): Promise<never> {
    return this.unavailable();
  }
}
