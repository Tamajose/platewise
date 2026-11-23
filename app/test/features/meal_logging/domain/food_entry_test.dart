import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/meal_logging/domain/food_entry.dart';

import '../fakes.dart';

FoodEntryResult build({
  FoodItem? initial,
  String name = 'Dal',
  String quantity = '1',
  String unit = 'bowl',
  String low = '140',
  String high = '220',
  bool customRange = false,
}) => buildFood(
  initial: initial,
  name: name,
  quantity: quantity,
  unit: unit,
  low: low,
  high: high,
  customRange: customRange,
);

void main() {
  group('quantity', () {
    test('accepts amounts with up to three decimals', () {
      expect(parseQuantity('1'), 1);
      expect(parseQuantity(' 0.5 '), 0.5);
      expect(parseQuantity('0.001'), 0.001);
      expect(parseQuantity('3000'), 3000);
    });

    test('rejects text, zero, huge and over-precise amounts', () {
      for (final bad in ['', 'abc', '0', '0.0004', '3000.1', '1.2345', 'NaN']) {
        expect(parseQuantity(bad), isNull, reason: bad);
      }
    });
  });

  group('calories', () {
    test('accepts whole numbers from 0 to 6,000', () {
      expect(parseCalories('0'), 0);
      expect(parseCalories(' 6000 '), 6000);
    });

    test('rejects everything else', () {
      for (final bad in ['', '-1', '6001', '1.5', 'x']) {
        expect(parseCalories(bad), isNull, reason: bad);
      }
    });
  });

  group('a new food', () {
    test('takes the range that was typed', () {
      final result = build();
      expect(result.error, isNull);
      final food = result.item!;
      expect(food.name, 'Dal');
      expect(food.range.low, 140);
      expect(food.range.high, 220);
      expect(food.nutrients, isEmpty);
      expect(food.provenance, 'manual');
    });

    test('a food measured in grams records the grams', () {
      final food = build(unit: 'g', quantity: '150').item!;
      expect(food.grams, 150);
      expect(build(unit: 'cup').item!.grams, isNull);
    });

    test('needs a valid quantity and range', () {
      expect(build(quantity: '0').error, quantityMessage);
      expect(build(low: '').error, caloriesMessage);
      expect(build(high: '9999').error, caloriesMessage);
    });

    test('rejects a high estimate below the low estimate', () {
      expect(
        build(low: '300', high: '200').error,
        'The high estimate must be at least the low estimate.',
      );
    });

    test('a weight in grams is limited by the quantity maximum', () {
      expect(build(unit: 'g', quantity: '3001').error, quantityMessage);
      expect(build(unit: 'g', quantity: '3000').item!.grams, 3000);
    });
  });

  group('an existing food', () {
    test('a new quantity scales the stored estimate and nutrients', () {
      final result = build(
        initial: rice,
        name: 'Steamed rice',
        unit: 'cup',
        quantity: '2',
        low: '1',
        high: '2',
      );
      final food = result.item!;
      expect(food.range.low, 350);
      expect(food.range.high, 450);
      expect(food.nutrients[Nutrient.protein], 8);
      expect(food.provenance, 'scaled');
    });

    test('a typed range replaces the stored one and drops nutrients', () {
      final food = build(
        initial: rice,
        name: 'Steamed rice',
        unit: 'cup',
        low: '100',
        high: '120',
        customRange: true,
      ).item!;
      expect(food.range.low, 100);
      expect(food.nutrients, isEmpty);
    });

    test('a different name or unit counts as a new food', () {
      expect(isReplacementFood(rice, 'Steamed rice', 'cup'), isFalse);
      expect(isReplacementFood(rice, ' Steamed rice ', 'cup'), isFalse);
      expect(isReplacementFood(rice, 'Fried rice', 'cup'), isTrue);
      expect(isReplacementFood(rice, 'Steamed rice', 'bowl'), isTrue);
      expect(isReplacementFood(null, 'x', 'cup'), isTrue);
    });

    test('scaling past the supported weight is rejected', () {
      const heavy = FoodItem(
        name: 'Stew',
        quantity: 1,
        unit: 'serving',
        grams: 5000,
        range: CalorieRange(100, 120),
      );
      final result = build(
        initial: heavy,
        name: 'Stew',
        unit: 'serving',
        quantity: '3',
      );
      expect(result.item, isNull);
      expect(result.error, contains('outside the supported estimate range'));
    });

    test('scaling past a nutrient limit is rejected', () {
      const protein = FoodItem(
        name: 'Whey',
        quantity: 1,
        unit: 'serving',
        range: CalorieRange(100, 120),
        nutrients: {Nutrient.protein: 600},
      );
      final result = build(
        initial: protein,
        name: 'Whey',
        unit: 'serving',
        quantity: '2',
      );
      expect(result.item, isNull);
      expect(result.error, contains('outside the supported estimate range'));
    });
  });

  group('logging a meal', () {
    test('needs a food', () {
      expect(canLogMeal(draftOf([])), isFalse);
      expect(canLogMeal(draftOf([rice])), isTrue);
    });

    test('is capped at 20,000 kcal', () {
      const big = FoodItem(
        name: 'Feast',
        quantity: 1,
        unit: 'serving',
        range: CalorieRange(6000, 6000),
      );
      expect(canLogMeal(draftOf([big, big, big])), isTrue);
      expect(canLogMeal(draftOf([big, big, big, big])), isFalse);
    });
  });
}
