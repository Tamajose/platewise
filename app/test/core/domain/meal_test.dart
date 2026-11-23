import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';

const rice = FoodItem(
  name: 'Steamed rice',
  quantity: 1,
  unit: 'cup',
  grams: 160,
  range: CalorieRange(175, 225),
  nutrients: {Nutrient.protein: 4, Nutrient.carbohydrate: 44},
  nutrientSource: 'seeded',
  provenance: 'demo',
);
const dal = FoodItem(
  name: 'Masoor dal',
  quantity: 1,
  unit: 'bowl',
  grams: 150,
  range: CalorieRange(140, 220),
  nutrients: {Nutrient.protein: 11, Nutrient.fiber: 6},
  nutrientSource: 'seeded',
  provenance: 'demo',
);

void main() {
  group('CalorieRange', () {
    test('representative arithmetic preserves an over-target range', () {
      const range = CalorieRange(1190, 1641);
      expect(range.midpoint, 1416);
      expect(range.remaining(1200).low, -441);
      expect(range.remaining(1200).high, 10);
    });

    test('labels and addition', () {
      expect(const CalorieRange(300, 300).label, '300');
      expect(const CalorieRange(300, 400).label, '300–400');
      final sum = const CalorieRange(100, 200) + const CalorieRange(50, 60);
      expect((sum.low, sum.high), (150, 260));
      expect(CalorieRange.zero.midpoint, 0);
    });
  });

  group('FoodItem', () {
    test('portion correction preserves nutrient availability', () {
      final item = rice.scale(1.5);
      expect(item.range.low, 263);
      expect(item.nutrients[Nutrient.protein], 6);
      expect(item.nutrients[Nutrient.sodium], isNull);
      expect(item.provenance, 'scaled');
      expect(nutrientTotals([item, dal])[Nutrient.carbohydrate], (
        value: 66.0,
        known: 1,
        total: 2,
      ));
    });

    test('portion text drops a trailing .0', () {
      expect(rice.portion, '1 cup');
      expect(rice.scale(1.5).portion, '1.5 cup');
    });

    test('nutrient totals report absence rather than zero', () {
      final totals = nutrientTotals([rice, dal]);
      expect(totals[Nutrient.fat]!.value, isNull);
      expect(totals[Nutrient.fat]!.known, 0);
      expect(totals[Nutrient.protein]!.value, 15);
      expect(totals[Nutrient.protein]!.total, 2);
    });
  });

  group('MealDraft', () {
    const draft = MealDraft(
      id: 'm1',
      source: MealSource.photo,
      items: [rice, dal],
      confidence: Confidence.high,
      assumptions: ['two scoops'],
      imagePath: 'u/p.jpg',
      model: 'm',
      question: 'q',
      expectedUpdatedAt: 't1',
    );

    test('range and title combine the items', () {
      expect(draft.range.low, 315);
      expect(draft.range.high, 445);
      expect(draft.title, 'Steamed rice · Masoor dal');
      expect(
        const MealDraft(id: 'x', source: MealSource.manual, items: []).title,
        'Meal draft',
      );
      expect(draft.isSaved, isTrue);
    });

    test('an edit marks the draft edited and drops confidence to low', () {
      final edited = draft.revise([rice]);
      expect(edited.edited, isTrue);
      expect(edited.confidence, Confidence.low);
      expect(edited.items, [rice]);
      expect(edited.expectedUpdatedAt, 't1');
      expect(edited.assumptions, ['two scoops']);
    });

    test('choosing a new source starts a new unsaved draft', () {
      final chosen = draft.choose(MealSource.comparison);
      expect(chosen.source, MealSource.comparison);
      expect(chosen.isSaved, isFalse);
      expect(chosen.confidence, Confidence.high);
    });

    test('a saved meal exposes an editable draft with its revision', () {
      final saved = SavedMeal(
        draft.choose(MealSource.photo),
        DateTime.utc(2026, 11, 22),
        'rev-2',
        380,
      );
      expect(saved.id, 'm1');
      expect(saved.range.low, 315);
      expect(saved.editable.expectedUpdatedAt, 'rev-2');
      expect(saved.editable.items, hasLength(2));
    });
  });
}
