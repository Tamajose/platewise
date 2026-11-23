import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/theme/plate_theme.dart';
import 'package:platewise/features/weekly/data/weekly_providers.dart';
import 'package:platewise/features/weekly/data/weekly_repositories.dart';
import 'package:platewise/features/weekly/domain/weekly_repository.dart';
import 'package:platewise/features/weekly/presentation/progress_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

import '../meal_logging/fakes.dart';

class FakeWeekly implements WeeklyRepository {
  Object? error;
  int calls = 0;
  @override
  Future<({String state, List<String> sentences})> summary() async {
    calls++;
    if (error != null) throw error!;
    return (state: 'ok', sentences: ['A calm week.']);
  }
}

/// Two logged days this week, so the summary has facts to work from.
Overview twoDays() {
  final base = Overview(
    profile: const Profile(height: 170, weight: 70, target: 2000),
    targets: const [TargetSnapshot('2020-01-01', 2000)],
  );
  final today = base.todayDate;
  SavedMeal meal(String id, DateTime day) => SavedMeal(
    MealDraft(id: id, source: MealSource.text, items: const [rice]),
    DateTime.utc(day.year, day.month, day.day, 6),
    'rev',
    200,
  );
  return base.copyWith(meals: [meal('a', today), meal('b', dayAt(today, -1))]);
}

void main() {
  setUpAll(timezone.initializeTimeZones);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('the demo summary states the same facts as the screen', () async {
    final store = DemoStore(SharedPreferencesAsync());
    await store.update((_) => twoDays());
    final summary = await DemoWeeklyRepository(store).summary();
    expect(summary.state, 'local');
    expect(summary.sentences.first, 'You logged meals on 2 of 7 days.');
    await store.update((_) => const Overview());
    expect((await DemoWeeklyRepository(store).summary()).state, 'insufficient');
  });

  Future<(Rig, FakeWeekly)> show(
    WidgetTester tester,
    Overview data, {
    bool demo = false,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rig = Rig(demo: demo, overview: data);
    final weekly = FakeWeekly();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...rig.overrides,
          weeklyRepositoryProvider.overrideWithValue(weekly),
        ],
        child: MaterialApp(
          theme: plateTheme(),
          home: const Scaffold(body: ProgressScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (rig, weekly);
  }

  testWidgets('an empty week asks for more logs', (tester) async {
    await show(tester, const Overview());
    expect(find.text('Intake and target'), findsOneWidget);
    expect(find.text('No meals logged in this window.'), findsOneWidget);
    expect(find.text('0 / 7 days'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('More logs needed'), findsOneWidget);
  });

  testWidgets('two logged days show coverage, averages and nutrients', (
    tester,
  ) async {
    await show(tester, twoDays());
    expect(find.text('2 / 7 days'), findsOneWidget);
    expect(
      find.textContaining('Mean logged intake: 200 kcal on 2 days.'),
      findsOneWidget,
    );
    expect(find.textContaining('Mean target: 2,000 kcal'), findsOneWidget);
    expect(find.textContaining('≈8 g'), findsOneWidget);
    expect(find.text('Generate weekly summary'), findsOneWidget);
  });

  testWidgets('the AI summary is generated on request', (tester) async {
    final (_, weekly) = await show(tester, twoDays());
    await tester.tap(find.text('Generate weekly summary'));
    await tester.pumpAndSettle();
    expect(weekly.calls, 1);
    expect(find.text('A calm week.'), findsOneWidget);
    expect(find.text('Generate weekly summary'), findsNothing);
  });

  testWidgets('a failed summary says why and can be retried', (tester) async {
    final rig = Rig(overview: twoDays());
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final weekly = FakeWeekly()..error = const Failure('Summary is down.');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...rig.overrides,
          weeklyRepositoryProvider.overrideWithValue(weekly),
        ],
        child: MaterialApp(
          theme: plateTheme(),
          home: const Scaffold(body: ProgressScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate weekly summary'));
    await tester.pumpAndSettle();
    expect(find.text('Summary is down.'), findsOneWidget);
    weekly.error = null;
    await tester.tap(find.text('Generate weekly summary'));
    await tester.pumpAndSettle();
    expect(find.text('A calm week.'), findsOneWidget);
  });

  testWidgets('demo mode shows the recap without calling a service', (
    tester,
  ) async {
    final (_, weekly) = await show(tester, twoDays(), demo: true);
    expect(find.text('Weekly recap'), findsOneWidget);
    expect(find.text('You logged meals on 2 of 7 days.'), findsOneWidget);
    expect(find.text('Generate weekly summary'), findsNothing);
    expect(weekly.calls, 0);
  });

  testWidgets('sample history is labeled', (tester) async {
    await show(tester, const Overview(sampleHistory: true));
    expect(find.text('Sample history'), findsOneWidget);
  });
}
