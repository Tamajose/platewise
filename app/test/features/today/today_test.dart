import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/app/app.dart';
import 'package:platewise/app/entry_route.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/presentation/routes.dart';
import 'package:platewise/features/onboarding/data/onboarding_providers.dart';
import 'package:platewise/features/onboarding/data/onboarding_repositories.dart';
import 'package:platewise/features/today/data/today_providers.dart';
import 'package:platewise/features/today/data/today_repositories.dart';
import 'package:platewise/features/today/domain/today_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

import '../meal_logging/fakes.dart';

class FakeToday implements TodayRepository {
  final deleted = <String>[];
  Object? error;
  @override
  Future<void> deleteMeal(String id) async {
    if (error != null) throw error!;
    deleted.add(id);
  }
}

final day = DateTime.utc(2026, 6, 1);

SavedMeal meal(String id, {int hour = 6}) => SavedMeal(
  MealDraft(id: id, source: MealSource.text, items: const [rice]),
  DateTime.utc(2026, 6, 1, hour),
  'rev',
  200,
);

Overview overview({
  List<SavedMeal> meals = const [],
  int pending = 0,
  bool profile = true,
}) => Overview(
  profile: profile
      ? const Profile(height: 170, weight: 70, target: 2000)
      : null,
  meals: meals,
  targets: const [TargetSnapshot('2026-01-01', 2000)],
  localDay: day,
  pendingAssets: pending,
);

void main() {
  setUpAll(timezone.initializeTimeZones);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('entry route', () {
    test(
      'a pending deletion goes to settings, no profile to welcome, else today',
      () {
        expect(
          entryRoute(const Overview(deletionPending: true)),
          Routes.settings,
        );
        expect(entryRoute(overview(profile: false)), Routes.welcome);
        expect(entryRoute(overview()), Routes.today);
        expect(
          entryRoute(
            Overview(profile: overview().profile, deletionPending: true),
          ),
          Routes.settings,
        );
      },
    );
  });

  group('demo repository', () {
    test('deleting removes only that meal', () async {
      final store = DemoStore(SharedPreferencesAsync());
      await store.update((_) => overview(meals: [meal('a'), meal('b')]));
      await DemoTodayRepository(store).deleteMeal('a');
      expect((await store.read()).meals.map((m) => m.id), ['b']);
    });
  });

  group('screen', () {
    Future<(Rig, FakeToday)> show(
      WidgetTester tester,
      Overview data, {
      double width = 700,
    }) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rig = Rig(overview: data);
      final today = FakeToday();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            todayRepositoryProvider.overrideWithValue(today),
            onboardingRepositoryProvider.overrideWithValue(
              const LiveOnboardingRepository(),
            ),
          ],
          child: const PlateWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      return (rig, today);
    }

    testWidgets('opens on Today with the summary and no meals', (tester) async {
      await show(tester, overview());
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Monday, June 1'), findsOneWidget);
      expect(find.text('No meals logged yet'), findsOneWidget);
      expect(find.text('2,000'), findsOneWidget);
      expect(find.text('kcal remaining'), findsOneWidget);
    });

    testWidgets('lists meals and shows what is left', (tester) async {
      await show(tester, overview(meals: [meal('a'), meal('b', hour: 9)]));
      expect(find.text('Steamed rice'), findsNWidgets(2));
      expect(find.text('1,600'), findsOneWidget);
      expect(find.text('400 logged · 2,000 target'), findsOneWidget);
    });

    testWidgets('a profile without a target asks for one', (tester) async {
      await show(
        tester,
        const Overview(profile: Profile(height: 170, weight: 70, target: null)),
      );
      expect(find.text('Set a target in Settings'), findsOneWidget);
    });

    testWidgets('deleting a meal asks first, then removes it', (tester) async {
      final (_, today) = await show(tester, overview(meals: [meal('a')]));
      await tester.tap(find.byTooltip('Actions for Steamed rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete meal'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this meal?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete meal'));
      await tester.pumpAndSettle();
      expect(today.deleted, ['a']);
      expect(find.text('Meal deleted'), findsOneWidget);
    });

    testWidgets('a failed delete says why', (tester) async {
      final rig = Rig(overview: overview(meals: [meal('a')]));
      tester.view.physicalSize = const Size(700, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final today = FakeToday()..error = const Failure('Could not delete.');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            todayRepositoryProvider.overrideWithValue(today),
            onboardingRepositoryProvider.overrideWithValue(
              const LiveOnboardingRepository(),
            ),
          ],
          child: const PlateWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actions for Steamed rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete meal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete meal'));
      await tester.pumpAndSettle();
      expect(find.text('Could not delete.'), findsOneWidget);
    });

    testWidgets('a pending photo cleanup can be retried', (tester) async {
      final (rig, _) = await show(tester, overview(pending: 1));
      expect(
        find.text('A removed photo is still pending cleanup.'),
        findsOneWidget,
      );
      final before = rig.overviews.reads;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(rig.overviews.reads, greaterThan(before));
    });

    testWidgets('Log meal opens capture and the bar moves between screens', (
      tester,
    ) async {
      await show(tester, overview());
      await tester.tap(find.text('Log meal'));
      await tester.pumpAndSettle();
      expect(find.text('What did you eat?'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nearby'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a search area'), findsOneWidget);
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(find.text('Intake and target'), findsOneWidget);
    });

    testWidgets('a new person lands on the welcome placeholder', (
      tester,
    ) async {
      await show(tester, overview(profile: false));
      expect(find.text('Decide before you eat'), findsOneWidget);
    });

    testWidgets('a wide window uses the side rail', (tester) async {
      await show(tester, overview(), width: 1300);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a failed start shows the reason and retries', (tester) async {
      tester.view.physicalSize = const Size(700, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rig = Rig()..overviews.error = const Failure('Service is down.');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            todayRepositoryProvider.overrideWithValue(FakeToday()),
            onboardingRepositoryProvider.overrideWithValue(
              const LiveOnboardingRepository(),
            ),
          ],
          child: const PlateWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Service is down.'), findsOneWidget);
      rig.overviews.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Decide before you eat'), findsOneWidget);
    });
  });
}
