import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';

void main() {
  test('copyWith replaces lists and keeps everything else', () {
    final original = Overview(
      profile: const Profile(height: 170, weight: 70, target: 1800),
      localDay: DateTime.utc(2026, 11, 22),
      pendingAssets: 3,
      deletionPending: true,
      deletionAccount: true,
      sampleHistory: true,
    );
    final meal = SavedMeal(
      const MealDraft(id: 'm', source: MealSource.manual, items: []),
      DateTime.utc(2026, 11, 22),
      'rev',
      0,
    );
    final copy = original.copyWith(meals: [meal]);
    expect(copy.meals, [meal]);
    expect(copy.profile!.target, 1800);
    expect(copy.localDay, DateTime.utc(2026, 11, 22));
    expect(copy.pendingAssets, 3);
    expect(copy.deletionPending, isTrue);
    expect(copy.deletionAccount, isTrue);
    expect(copy.sampleHistory, isTrue);
    expect(original.meals, isEmpty);
  });

  test('copyWith without arguments is an equal copy', () {
    const original = Overview(
      profile: Profile(height: 170, weight: 70, target: null),
    );
    final copy = original.copyWith();
    expect(copy.profile, same(original.profile));
    expect(copy.meals, isEmpty);
  });
}
