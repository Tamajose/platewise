import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/theme/plate_theme.dart';
import 'package:platewise/features/settings/data/export_providers.dart';
import 'package:platewise/features/settings/data/settings_providers.dart';
import 'package:platewise/features/settings/domain/settings_repository.dart';
import 'package:platewise/features/settings/domain/stats_export.dart';
import 'package:platewise/features/settings/presentation/export_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

import '../meal_logging/fakes.dart';

final today = DateTime.utc(2026, 6, 30);

SavedMeal mealOn(int daysAgo, int kcal) => SavedMeal(
  draftOf([rice]),
  DateTime.utc(2026, 6, 30 - daysAgo, 6),
  'rev',
  kcal,
);

/// Ten days of records, ending today.
Overview history() => Overview(
  profile: const Profile(height: 170, weight: 70, target: 2000),
  targets: const [TargetSnapshot('2026-01-01', 2000)],
  localDay: today,
  meals: [mealOn(0, 500), mealOn(0, 700), mealOn(9, 900)],
  water: [WaterEntry('w', DateTime.utc(2026, 6, 28, 8), 250, 'r')],
);

class FakeExportSettings implements SettingsRepository {
  final asked = <int>[];
  Object? error;
  @override
  Future<StatsExport> exportStats(int days) async {
    asked.add(days);
    if (error != null) throw error!;
    return StatsExport.fromOverview(history(), days);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(timezone.initializeTimeZones);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the window', () {
    test('is a week to a year and stops where the records start', () {
      expect(exportWindow(3, 400), minExportDays);
      expect(exportWindow(500, 1000), maxExportDays);
      expect(exportWindow(365, 10), 10 < minExportDays ? 7 : 10);
      expect(exportWindow(365, 3), minExportDays);
      expect(exportWindow(30, 100), 30);
      expect(exportWindow(30, 20), 20);
    });

    test('an export asked for a year holds only the days that exist', () {
      final export = StatsExport.fromOverview(history(), 365);
      expect(export.availableDays, 10);
      expect(export.days, 10);
      expect(export.shortened, isTrue);
      expect(export.rows.first.day, DateTime.utc(2026, 6, 21));
      expect(export.rows.last.day, today);
    });

    test('a short history still gives a full week', () {
      final export = StatsExport.fromOverview(
        history().copyWith(meals: [mealOn(0, 500)], water: []),
        90,
      );
      expect(export.days, 7);
      expect(export.rows, hasLength(7));
    });
  });

  group('the file', () {
    test('has one row a day with ranges, estimate, target and water', () {
      final lines = StatsExport.fromOverview(
        history(),
        7,
      ).toCsv().trim().split('\r\n');
      expect(
        lines.first,
        'date,target_kcal,meals,kcal_low,kcal_high,kcal_estimate,target_comparison,water_ml',
      );
      expect(lines, hasLength(8));
      expect(lines.last, '2026-06-30,2000,2,350,450,1200,below,0');
      expect(lines[lines.length - 3], '2026-06-28,2000,0,,,,,250');
    });

    test('is named for the days it holds', () {
      expect(
        StatsExport.fromOverview(history(), 7).fileName,
        'platewise-stats-2026-06-24-to-2026-06-30.csv',
      );
    });
  });

  group('the screen', () {
    Future<(FakeExportSettings, List<String>)> show(
      WidgetTester tester, {
      bool allowed = false,
    }) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeExportSettings();
      final saved = <String>[];
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          saveExportProvider.overrideWithValue((name, text) async {
            saved.add(name);
            return 'Downloads';
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exportPermissionProvider.future);
      if (allowed) {
        await container.read(exportPermissionProvider.notifier).set(true);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: plateTheme(), home: const ExportScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return (repo, saved);
    }

    testWidgets('asks for permission first and keeps it off by default', (
      tester,
    ) async {
      final (repo, _) = await show(tester);
      expect(find.text('Allow data export'), findsOneWidget);
      expect(find.text('Prepare export'), findsNothing);
      await tester.tap(find.text('Allow data export'));
      await tester.pumpAndSettle();
      expect(find.text('Prepare export'), findsOneWidget);
      expect(repo.asked, isEmpty);
    });

    testWidgets('exports the chosen days and saves the file', (tester) async {
      final (repo, saved) = await show(tester, allowed: true);
      await tester.tap(find.text('1 week'));
      await tester.pump();
      expect(find.text('Last 7 days'), findsOneWidget);
      await tester.tap(find.text('Prepare export'));
      await tester.pumpAndSettle();
      expect(repo.asked, [7]);
      expect(find.text('7 days · 1 with meals · 2 meals'), findsOneWidget);
      await tester.tap(find.text('Save CSV file'));
      await tester.pumpAndSettle();
      expect(saved, ['platewise-stats-2026-06-24-to-2026-06-30.csv']);
      expect(find.textContaining('to Downloads'), findsOneWidget);
    });

    testWidgets('says when a year was asked for but fewer days exist', (
      tester,
    ) async {
      await show(tester, allowed: true);
      await tester.tap(find.text('1 year'));
      await tester.pump();
      await tester.tap(find.text('Prepare export'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('asked for 365 days, but your records cover 10'),
        findsOneWidget,
      );
    });

    testWidgets('shows a failure and offers no file', (tester) async {
      final (repo, _) = await show(tester, allowed: true);
      repo.error = const Failure('The service is down.');
      await tester.tap(find.text('Prepare export'));
      await tester.pumpAndSettle();
      expect(find.text('The service is down.'), findsOneWidget);
      expect(find.text('Save CSV file'), findsNothing);
    });

    testWidgets('changing the period clears the prepared export', (
      tester,
    ) async {
      await show(tester, allowed: true);
      await tester.tap(find.text('Prepare export'));
      await tester.pumpAndSettle();
      expect(find.text('Save CSV file'), findsOneWidget);
      await tester.tap(find.text('1 month'));
      await tester.pump();
      expect(find.text('Save CSV file'), findsNothing);
    });
  });
}
