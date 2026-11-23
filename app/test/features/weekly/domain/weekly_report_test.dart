import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/weekly/domain/weekly_report.dart';

SavedMeal meal(int low, int high) => SavedMeal(
  MealDraft(
    id: 'm$low',
    source: MealSource.manual,
    items: [
      FoodItem(
        name: 'food',
        quantity: 1,
        unit: 'serving',
        range: CalorieRange(low, high),
      ),
    ],
  ),
  DateTime.utc(2026, 11, 22),
  'rev',
  ((low + high) / 2).round(),
);

DayLog day(
  int index, {
  int? target,
  List<SavedMeal> meals = const [],
  int water = 0,
}) => DayLog(
  DateTime.utc(2026, 11, 16 + index),
  target,
  meals,
  water == 0
      ? const []
      : [WaterEntry('w$index', DateTime.utc(2026, 11, 16 + index), water, 'r')],
);

void main() {
  test('one logged day is not enough to state facts', () {
    final report = WeeklyReport([
      day(0, target: 1800, meals: [meal(1700, 1900)]),
      ...[for (var i = 1; i < 7; i++) day(i)],
    ]);
    expect(report.logged, hasLength(1));
    expect(report.facts, isEmpty);
  });

  test('averages, target pairing and overlap use only logged days', () {
    final report = WeeklyReport([
      day(0, target: 1800, meals: [meal(1700, 1900)], water: 500),
      day(1, target: 1800, meals: [meal(1000, 1200)]),
      day(2, meals: [meal(1500, 1500)]),
      ...[for (var i = 3; i < 7; i++) day(i, target: 1800)],
    ]);
    expect(report.logged, hasLength(3));
    expect(report.paired, hasLength(2));
    expect(report.overlap, 1);
    // Midpoints 1800, 1100 and 1500 average 1466.7.
    expect(report.average, 1467);
    expect(report.targetAverage, 1800);
    expect(report.items, hasLength(3));
  });

  test('facts describe logging, intake, target overlap and water', () {
    final report = WeeklyReport([
      day(0, target: 1800, meals: [meal(1700, 1900)], water: 500),
      day(1, target: 1800, meals: [meal(1000, 1200)]),
      ...[for (var i = 2; i < 7; i++) day(i)],
    ]);
    expect(report.facts, [
      'You logged meals on 2 of 7 days.',
      'Logged intake averaged about 1450 kcal on those days.',
      'The recorded calorie range overlapped the target on 1 of 2 logged days with a target.',
      'You logged water on 1 of 7 days.',
    ]);
  });

  test('an empty week has no averages', () {
    final report = WeeklyReport([for (var i = 0; i < 7; i++) day(i)]);
    expect(report.average, isNull);
    expect(report.targetAverage, isNull);
    expect(report.overlap, 0);
  });
}
