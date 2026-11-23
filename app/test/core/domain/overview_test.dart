import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

SavedMeal meal(String id, String instant, int low, int high) => SavedMeal(
  MealDraft(
    id: id,
    source: MealSource.manual,
    items: [
      FoodItem(
        name: id,
        quantity: 1,
        unit: 'serving',
        range: CalorieRange(low, high),
      ),
    ],
  ),
  DateTime.parse(instant),
  'rev',
  ((low + high) / 2).round(),
);

void main() {
  setUpAll(timezone.initializeTimeZones);

  test('an instant crosses the selected local day boundary', () {
    final instant = DateTime.parse('2026-11-21T18:30Z');
    expect(dayKey(localTime(instant, 'Asia/Dhaka')), '2026-11-22');
    expect(dayKey(localTime(instant, 'America/New_York')), '2026-11-21');
  });

  test('day arithmetic is calendar based', () {
    final day = dayAt(DateTime.utc(2026, 12, 31, 15), 1);
    expect(dayKey(day), '2027-01-01');
    expect(dayKey(DateTime.utc(7, 3, 9)), '0007-03-09');
  });

  group('Overview', () {
    final overview = Overview(
      profile: const Profile(
        height: 170,
        weight: 70,
        target: 1800,
        zone: 'Asia/Dhaka',
      ),
      localDay: DateTime.utc(2026, 11, 22),
      targets: const [
        TargetSnapshot('2026-11-01', 2000),
        TargetSnapshot('2026-11-20', 1800),
        TargetSnapshot('2026-12-01', 1500),
      ],
      meals: [
        // 18:30Z on the 21st is already the 22nd in Dhaka.
        meal('late', '2026-11-21T18:30:00Z', 400, 600),
        meal('noon', '2026-11-22T06:00:00Z', 500, 700),
        meal('earlier', '2026-11-21T06:00:00Z', 300, 300),
      ],
      water: [
        WaterEntry('w1', DateTime.utc(2026, 11, 22, 1), 250, 'r'),
        WaterEntry('w2', DateTime.utc(2026, 11, 22, 3), 500, 'r'),
      ],
    );

    test('groups meals by the local day, in time order', () {
      final today = overview.today;
      expect(today.meals.map((m) => m.id), ['late', 'noon']);
      expect(today.intake.low, 900);
      expect(today.intake.high, 1300);
      expect(today.representative, 500 + 600);
      expect(today.waterMl, 750);
    });

    test('uses the target effective on that date, not the latest', () {
      expect(overview.forDay(DateTime.utc(2026, 11, 10)).target, 2000);
      expect(overview.today.target, 1800);
      expect(overview.forDay(DateTime.utc(2026, 12, 5)).target, 1500);
    });

    test('the week is seven days ending today', () {
      final week = overview.week;
      expect(week, hasLength(7));
      expect(dayKey(week.first.day), '2026-11-16');
      expect(dayKey(week.last.day), '2026-11-22');
      expect(week[5].meals.map((m) => m.id), ['earlier']);
    });

    test('zone falls back to Dhaka without a profile', () {
      expect(const Overview().zone, 'Asia/Dhaka');
    });
  });

  group('DayLog.targetRelation', () {
    DayLog day(int? target, List<SavedMeal> meals) =>
        DayLog(DateTime.utc(2026, 11, 22), target, meals, const []);

    test('is absent without meals or without a target', () {
      expect(day(1800, const []).targetRelation, isNull);
      expect(
        day(null, [meal('a', '2026-11-22T00:00Z', 1, 2)]).targetRelation,
        isNull,
      );
    });

    test('compares the whole recorded range with the target', () {
      expect(
        day(1800, [meal('a', '2026-11-22T00:00Z', 1000, 1700)]).targetRelation,
        'Below',
      );
      expect(
        day(1800, [meal('a', '2026-11-22T00:00Z', 1900, 2100)]).targetRelation,
        'Above',
      );
      expect(
        day(1800, [meal('a', '2026-11-22T00:00Z', 1700, 1900)]).targetRelation,
        'Overlaps',
      );
      expect(
        day(1800, [meal('a', '2026-11-22T00:00Z', 1800, 1800)]).targetRelation,
        'Overlaps',
      );
    });
  });
}
