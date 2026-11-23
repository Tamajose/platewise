import '../../../core/domain/calorie_range.dart';
import '../../../core/domain/food_item.dart';
import '../../../core/domain/meal.dart';
import '../../../core/domain/nutrient.dart';

/// The largest calorie range one meal may add up to.
const maxMealCalories = 20000;

/// The most foods one meal may hold.
const maxFoodsPerMeal = 16;

/// The largest low or high estimate for a single food.
const maxFoodCalories = 6000;

const _maxQuantity = 3000.0;
const _minQuantity = 0.001;
const _maxGrams = 12000;
const _nutrientLimits = {
  Nutrient.protein: 1000,
  Nutrient.carbohydrate: 1500,
  Nutrient.fat: 1000,
  Nutrient.fiber: 300,
  Nutrient.sodium: 50000,
};

/// Whether [draft] may be added to the log.
bool canLogMeal(MealDraft draft) =>
    draft.items.isNotEmpty && draft.range.high <= maxMealCalories;

/// A quantity from typed text, or null when it is not a usable amount: between
/// 0.001 and 3,000 with at most three decimal places.
double? parseQuantity(String text) {
  final value = double.tryParse(text.trim());
  if (value == null || !value.isFinite) return null;
  if (value < _minQuantity || value > _maxQuantity) return null;
  if ((value * 1000 - (value * 1000).round()).abs() >= .000001) return null;
  return value;
}

const quantityMessage =
    'Enter 0.001 to 3,000 using up to three decimal places.';
const caloriesMessage = 'Enter 0–6,000 kcal.';

/// A calorie estimate from typed text, or null when it is not a whole number
/// from 0 to 6,000.
int? parseCalories(String text) {
  final value = int.tryParse(text.trim());
  return value == null || value < 0 || value > maxFoodCalories ? null : value;
}

/// Whether the person changed which food this is. A different name or unit
/// means the stored nutrition no longer applies.
bool isReplacementFood(FoodItem? initial, String name, String unit) =>
    initial == null || initial.name != name.trim() || initial.unit != unit;

/// The outcome of checking what a person typed for one food: an [item], or an
/// [error] to show them.
typedef FoodEntryResult = ({FoodItem? item, String? error});

/// Builds a food from the editor's fields.
///
/// Changing only the quantity of an existing food scales its stored estimate
/// and nutrients. Changing the name or unit, or typing a range, builds a new
/// food with that range and no nutrient data.
FoodEntryResult buildFood({
  FoodItem? initial,
  required String name,
  required String quantity,
  required String unit,
  required String low,
  required String high,
  required bool customRange,
}) {
  final amount = parseQuantity(quantity);
  if (amount == null) {
    return (item: null, error: quantityMessage);
  }
  final replaced = isReplacementFood(initial, name, unit);
  final FoodItem item;
  if (!replaced && !customRange) {
    item = initial!.scale(amount);
  } else {
    final lowest = parseCalories(low);
    final highest = parseCalories(high);
    if (lowest == null || highest == null) {
      return (item: null, error: caloriesMessage);
    }
    if (highest < lowest) {
      return (
        item: null,
        error: 'The high estimate must be at least the low estimate.',
      );
    }
    item = FoodItem(
      name: name.trim(),
      quantity: amount,
      unit: unit,
      range: CalorieRange(lowest, highest),
      grams: unit == 'g' ? amount : null,
    );
  }
  final tooMuch =
      (item.grams ?? 0) > _maxGrams ||
      Nutrient.values.any(
        (n) => (item.nutrients[n] ?? 0) > _nutrientLimits[n]!,
      );
  if (tooMuch) {
    return (
      item: null,
      error: 'This portion is outside the supported estimate range. Check the quantity.',
    );
  }
  return (item: item, error: null);
}
