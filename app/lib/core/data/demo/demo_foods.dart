import '../../domain/domain.dart';

/// The small food catalog that demo mode estimates from. The portions are
/// illustrative, not nutrition data.
abstract final class DemoFoods {
  static const rice = FoodItem(
    name: 'Steamed rice',
    quantity: 1,
    unit: 'cup',
    grams: 160,
    range: CalorieRange(175, 225),
    nutrients: {Nutrient.protein: 4, Nutrient.carbohydrate: 44},
    nutrientSource: 'seeded',
    provenance: 'demo',
  );
  static const dal = FoodItem(
    name: 'Masoor dal',
    quantity: 1,
    unit: 'bowl',
    grams: 150,
    range: CalorieRange(140, 220),
    nutrients: {Nutrient.protein: 11, Nutrient.fiber: 6},
    nutrientSource: 'seeded',
    provenance: 'demo',
  );
  static const eggs = FoodItem(
    name: 'Boiled eggs & toast',
    quantity: 1,
    unit: 'serving',
    range: CalorieRange(265, 350),
    nutrients: {Nutrient.protein: 17, Nutrient.fat: 13},
    nutrientSource: 'seeded',
    provenance: 'demo',
  );
  static const chicken = FoodItem(
    name: 'Chicken tikka rice bowl',
    quantity: 1,
    unit: 'bowl',
    range: CalorieRange(465, 590),
    nutrients: {Nutrient.protein: 29, Nutrient.carbohydrate: 66},
    nutrientSource: 'seeded',
    provenance: 'demo',
  );
  static const khichuri = FoodItem(
    name: 'Vegetable khichuri',
    quantity: 1,
    unit: 'bowl',
    range: CalorieRange(360, 490),
    nutrients: {Nutrient.protein: 13, Nutrient.fiber: 5},
    nutrientSource: 'seeded',
    provenance: 'demo',
  );
  static const biryani = FoodItem(
    name: 'Chicken biryani',
    quantity: 1,
    unit: 'serving',
    range: CalorieRange(640, 850),
    nutrients: {Nutrient.protein: 31},
    nutrientSource: 'seeded',
    provenance: 'demo',
  );

  /// Words in a description that select a food. The first matching entries win
  /// in list order, and a description can match several foods.
  static const catalog = [
    (keys: ['biryani', 'biriyani'], food: biryani),
    (keys: ['khichuri', 'khichdi'], food: khichuri),
    (keys: ['tikka'], food: chicken),
    (keys: ['egg', 'toast'], food: eggs),
    (keys: ['rice'], food: rice),
    (keys: ['dal', 'lentil'], food: dal),
  ];
}
