import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/data/json.dart';
import 'package:platewise/core/data/mappers/mappers.dart';
import 'package:platewise/core/domain/domain.dart';

/// Shaped like the API's `dashboard` response: table rows serialized as JSON,
/// including columns the app ignores.
Json dashboard() => {
  'profile': {
    'user_id': 'u1',
    'height_cm': 172.5,
    'weight_kg': 67,
    'daily_calorie_target': 1800,
    'water_goal_ml': 2000,
    'timezone': 'Asia/Dhaka',
    'preferred_units': 'metric',
    'preferred_language': 'en',
    'correction_consent': true,
    'consent_at': null,
    'created_at': '2026-11-01T00:00:00+00:00',
  },
  'local_day': '2026-11-22',
  'meals': [
    {
      'id': 'm1',
      'user_id': 'u1',
      'consumed_at': '2026-11-22T06:00:00+00:00',
      'source': 'photo',
      'status': 'confirmed',
      'image_storage_path': 'u1/p.jpg',
      'calorie_low': 175,
      'calorie_high': 225,
      'representative_calories': 200,
      'confidence': 'medium',
      'user_edited': false,
      'assumptions': ['Two scoops of rice.', ''],
      'model': 'gpt-4.1-mini',
      'updated_at': '2026-11-22T06:01:00.123456+00:00',
      'items': [
        {
          'name': 'Steamed rice',
          'normalized_food_reference': null,
          'quantity': 1,
          'unit': 'cup',
          'estimated_grams': 160,
          'calorie_low': 175,
          'calorie_high': 225,
          'protein_g': 4,
          'carbohydrate_g': 44.5,
          'fat_g': null,
          'fiber_g': null,
          'sodium_mg': null,
          'nutrient_source': 'seeded',
          'provenance': 'demo',
        },
      ],
    },
  ],
  'targets': [
    {'effective_on': '2026-11-01', 'target_kcal': 2000},
    {'effective_on': '2026-11-20', 'target_kcal': null},
  ],
  'water': [
    {
      'id': 'w1',
      'user_id': 'u1',
      'logged_at': '2026-11-22T01:00:00+00:00',
      'amount_ml': 250,
      'updated_at': '2026-11-22T01:00:01+00:00',
    },
  ],
  'pending_asset_count': 2,
  'deletion_pending': false,
  'deletion_account': false,
};

void main() {
  group('overview', () {
    test('reads a dashboard response and ignores extra columns', () {
      final overview = overviewFromJson(dashboard());

      final profile = overview.profile!;
      expect(profile.height, 172.5);
      expect(profile.weight, 67);
      expect(profile.target, 1800);
      expect(profile.zone, 'Asia/Dhaka');
      expect(profile.correctionConsent, isTrue);

      final meal = overview.meals.single;
      expect(meal.id, 'm1');
      expect(meal.draft.source, MealSource.photo);
      expect(meal.draft.confidence, Confidence.medium);
      expect(meal.draft.imagePath, 'u1/p.jpg');
      // A meal's range is the sum of its items, as the database stores it.
      expect(meal.range.low, 175);
      expect(meal.range.high, 225);
      expect(meal.representative, 200);
      expect(meal.at, DateTime.utc(2026, 11, 22, 6));
      // The revision string is echoed back unchanged to detect stale edits.
      expect(meal.updatedAt, '2026-11-22T06:01:00.123456+00:00');
      expect(meal.draft.assumptions, ['Two scoops of rice.']);

      final item = meal.draft.items.single;
      expect(item.nutrients[Nutrient.protein], 4);
      expect(item.nutrients[Nutrient.carbohydrate], 44.5);
      expect(item.nutrients[Nutrient.fat], isNull);
      expect(item.reference, isNull);
      expect(item.grams, 160);

      expect(overview.targets.map((t) => (t.day, t.target)), [
        ('2026-11-01', 2000),
        ('2026-11-20', null),
      ]);
      expect(overview.water.single.amount, 250);
      expect(overview.water.single.revision, '2026-11-22T01:00:01+00:00');
      expect(overview.localDay, DateTime.utc(2026, 11, 22));
      expect(overview.pendingAssets, 2);
      expect(overview.deletionPending, isFalse);
    });

    test('a missing profile and missing flags use safe defaults', () {
      final overview = overviewFromJson({'profile': null, 'meals': null});
      expect(overview.profile, isNull);
      expect(overview.meals, isEmpty);
      expect(overview.localDay, isNull);
      expect(overview.pendingAssets, 0);
      expect(overview.sampleHistory, isFalse);
    });

    test('the stored shape survives a JSON round trip', () {
      final original = overviewFromJson(dashboard());
      final stored = overviewToStoredJson(original);
      final revived = overviewFromJson(
        Json.from(jsonDecode(jsonEncode(stored)) as Map),
      );
      expect(overviewToStoredJson(revived), stored);
      expect(revived.meals.single.updatedAt, original.meals.single.updatedAt);
      expect(revived.profile!.correctionConsent, isTrue);
    });

    test('an empty overview stores and revives as empty', () {
      final stored = overviewToStoredJson(const Overview());
      expect(stored['profile'], isNull);
      expect(overviewFromJson(stored).profile, isNull);
    });
  });

  group('profile', () {
    const profile = Profile(
      height: 170,
      weight: 70,
      target: 1800,
      units: 'us',
      language: 'bn',
      correctionConsent: true,
    );

    test('the API shape carries the target confirmation', () {
      final json = profileToJson(profile, confirmed: true);
      expect(json['target_confirmed'], isTrue);
      expect(json.containsKey('correction_consent'), isFalse);
      expect(json['daily_calorie_target'], 1800);
      expect(json['preferred_units'], 'us');
    });

    test('the stored shape carries consent instead', () {
      final json = profileToJson(profile, stored: true);
      expect(json['correction_consent'], isTrue);
      expect(json.containsKey('target_confirmed'), isFalse);
      expect(profileFromJson(json).language, 'bn');
    });
  });

  group('meal drafts', () {
    test('an estimate without confidence defaults to low', () {
      final draft = mealDraftFromEstimate(
        {'items': <Object?>[]},
        id: 'd1',
        source: MealSource.text,
      );
      expect(draft.confidence, Confidence.low);
      expect(draft.edited, isFalse);
      expect(draft.items, isEmpty);
      expect(draft.id, 'd1');
    });

    test('non-text and empty assumptions are dropped', () {
      final draft = mealDraftFromEstimate(
        {
          'items': <Object?>[],
          'assumptions': ['one', '', 3, null],
        },
        id: 'd1',
        source: MealSource.text,
      );
      expect(draft.assumptions, ['one']);
    });

    test('an unknown confidence is rejected', () {
      expect(
        () => mealDraftFromEstimate(
          {'items': <Object?>[], 'confidence': 'certain'},
          id: 'd1',
          source: MealSource.text,
        ),
        throwsArgumentError,
      );
    });

    test('the revision is sent only for a saved meal', () {
      const unsaved = MealDraft(id: 'a', source: MealSource.manual, items: []);
      const saved = MealDraft(
        id: 'a',
        source: MealSource.manual,
        items: [],
        expectedUpdatedAt: 'rev-1',
      );
      expect(
        mealDraftToJson(unsaved).containsKey('expected_updated_at'),
        isFalse,
      );
      expect(mealDraftToJson(saved)['expected_updated_at'], 'rev-1');
      expect(mealDraftToJson(saved)['source'], 'manual');
    });

    test('a saved meal survives a round trip', () {
      final meal = overviewFromJson(dashboard()).meals.single;
      final again = savedMealFromJson(
        Json.from(jsonDecode(jsonEncode(savedMealToJson(meal))) as Map),
      );
      expect(again.id, meal.id);
      expect(again.at, meal.at);
      expect(again.updatedAt, meal.updatedAt);
      expect(again.representative, meal.representative);
      expect(again.draft.items.single.name, 'Steamed rice');
    });
  });

  group('food items', () {
    test('every nutrient key is written, absent values as null', () {
      const item = FoodItem(
        name: 'Dal',
        quantity: 1.5,
        unit: 'bowl',
        range: CalorieRange(140, 220),
        nutrients: {Nutrient.protein: 11},
      );
      final json = foodItemToJson(item);
      for (final nutrient in Nutrient.values) {
        expect(json.containsKey(nutrient.key), isTrue, reason: nutrient.key);
      }
      expect(json['protein_g'], 11);
      expect(json['fat_g'], isNull);
      expect(json['calorie_low'], 140);
      final back = foodItemFromJson(json);
      expect(back.quantity, 1.5);
      expect(back.nutrients[Nutrient.protein], 11);
      expect(back.nutrientSource, 'unavailable');
      expect(back.provenance, 'manual');
    });
  });

  group('budget fit', () {
    test('wire names map to fits', () {
      expect(budgetFitFromWire('no_budget'), BudgetFit.noBudget);
      expect(budgetFitFromWire('fits'), BudgetFit.fits);
      expect(budgetFitFromWire('overlaps'), BudgetFit.overlaps);
      expect(budgetFitFromWire('above'), BudgetFit.above);
      expect(() => budgetFitFromWire('nope'), throwsArgumentError);
    });
  });
}
