import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/app/app.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/onboarding/data/onboarding_providers.dart';
import 'package:platewise/features/onboarding/data/onboarding_repositories.dart';
import 'package:platewise/features/profile/data/profile_providers.dart';
import 'package:platewise/features/profile/data/profile_repositories.dart';
import 'package:platewise/features/profile/domain/profile_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

import '../meal_logging/fakes.dart';

ProfileInput input({
  String units = 'metric',
  String height = '170',
  String weight = '70',
  String target = '',
  String zone = 'Asia/Dhaka',
  String water = '2000',
  bool confirmed = false,
}) => ProfileInput(
  units: units,
  height: height,
  weight: weight,
  target: target,
  zone: zone,
  language: 'en',
  waterGoal: water,
  targetConfirmed: confirmed,
);

void main() {
  setUpAll(timezone.initializeTimeZones);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('profile rules', () {
    test('measurements are checked in the chosen units', () {
      expect(heightError('170', 'metric'), isNull);
      expect(heightError('99', 'metric'), 'Enter 100–250 cm.');
      expect(heightError('67', 'us'), isNull);
      expect(heightError('30', 'us'), 'Enter 39.38–98.42 inches.');
      expect(weightError('29', 'metric'), 'Enter 30–350 kg.');
      expect(weightError('154', 'us'), isNull);
      expect(weightError('abc', 'us'), isNotNull);
    });

    test('switching units keeps the same body', () {
      expect(convertHeight('170', 'metric', 'us'), '66.93');
      expect(convertHeight('66.93', 'us', 'metric'), '170.00');
      expect(convertWeight('70', 'metric', 'us'), '154.32');
      expect(convertHeight('x', 'metric', 'us'), 'x');
    });

    test('body mass index needs plausible measurements', () {
      expect(bmi('170', '70', 'metric')!.toStringAsFixed(1), '24.2');
      expect(bmi('50', '70', 'metric'), isNull);
    });

    test('timezone, target and water goal', () {
      expect(timezoneError('Asia/Dhaka'), isNull);
      expect(timezoneError('Mars/Base'), timezoneMessage);
      expect(targetFieldError(''), isNull);
      expect(targetFieldError('abc'), 'Enter a whole number.');
      expect(targetFieldError('900'), targetGuidance);
      expect(targetFieldError('1800'), isNull);
      expect(waterGoalError('499'), waterGoalMessage);
      expect(waterGoalError('5000'), isNull);
    });

    test('a profile is built in metric and rounded to a tenth', () {
      final built = buildProfile(
        input(
          units: 'us',
          height: '67',
          weight: '154',
          target: '1800',
          confirmed: true,
        ),
      );
      expect(built.error, isNull);
      expect(built.profile!.height, 170.2);
      expect(built.profile!.weight, 69.9);
      expect(built.profile!.target, 1800);
      expect(built.profile!.units, 'us');
    });

    test('a target needs the adult confirmation', () {
      expect(
        buildProfile(input(target: '1800')).error,
        targetConfirmationMessage,
      );
      expect(buildProfile(input()).profile!.target, isNull);
    });

    test('the first problem is reported', () {
      expect(buildProfile(input(height: '5')).error, 'Enter 100–250 cm.');
      expect(buildProfile(input(zone: 'x/y')).error, timezoneMessage);
    });
  });

  group('demo repositories', () {
    late DemoStore store;
    setUp(() => store = DemoStore(SharedPreferencesAsync()));

    test('saving a profile records the target from today', () async {
      final repo = DemoProfileRepository(store);
      await repo.save(
        buildProfile(input(target: '1800', confirmed: true)).profile!,
        targetConfirmed: true,
      );
      var overview = await store.read();
      expect(overview.profile!.target, 1800);
      expect(overview.targets.single.target, 1800);
      await repo.save(overview.profile!, targetConfirmed: true);
      expect((await store.read()).targets, hasLength(1));
    });

    test('a target outside the range or unconfirmed is refused', () async {
      final repo = DemoProfileRepository(store);
      const low = Profile(height: 170, weight: 70, target: 900);
      await expectLater(
        repo.save(low, targetConfirmed: true),
        throwsA(isA<Failure>()),
      );
      const ok = Profile(height: 170, weight: 70, target: 1800);
      await expectLater(
        repo.save(ok, targetConfirmed: false),
        throwsA(isA<Failure>()),
      );
      expect((await store.read()).profile, isNull);
    });

    test('the sample day fills five days of meals and water', () async {
      var n = 0;
      final repo = DemoOnboardingRepository(
        store,
        generateId: () => 'id-${n++}',
        now: () => DateTime.utc(2026, 6, 10, 6),
      );
      expect(repo.offersSampleDay, isTrue);
      await repo.startSampleDay();
      final overview = await store.read();
      expect(overview.sampleHistory, isTrue);
      expect(overview.profile!.target, 2050);
      expect(overview.water, hasLength(5));
      expect(overview.meals.length, greaterThanOrEqualTo(10));
      expect(
        overview.meals.map((m) => m.id).toSet().length,
        overview.meals.length,
      );
      expect(overview.targets, hasLength(2));
    });

    test('a live build offers no sample day', () async {
      const repo = LiveOnboardingRepository();
      expect(repo.offersSampleDay, isFalse);
      await expectLater(repo.startSampleDay(), throwsA(isA<Failure>()));
    });
  });

  group('screens', () {
    Future<DemoStore> open(WidgetTester tester, {bool demo = true}) async {
      tester.view.physicalSize = const Size(700, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = DemoStore(SharedPreferencesAsync());
      final rig = Rig(demo: demo);
      rig.overviews.source = store.read;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            profileRepositoryProvider.overrideWithValue(
              DemoProfileRepository(store),
            ),
            onboardingRepositoryProvider.overrideWithValue(
              demo
                  ? DemoOnboardingRepository(store)
                  : const LiveOnboardingRepository(),
            ),
          ],
          child: const PlateWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('a new person sees the welcome screen', (tester) async {
      await open(tester);
      expect(find.text('Decide before you eat'), findsOneWidget);
      expect(find.text('Explore a sample day'), findsOneWidget);
      expect(find.text('Demo mode'), findsOneWidget);
    });

    testWidgets('a live build offers sign in instead of a sample', (
      tester,
    ) async {
      await open(tester, demo: false);
      expect(find.text('Explore a sample day'), findsNothing);
      await tester.tap(find.text('Sign in to an existing account'));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsWidgets);
    });

    testWidgets('exploring a sample day opens Today with data', (tester) async {
      final store = await open(tester);
      await tester.tap(find.text('Explore a sample day'));
      await tester.pumpAndSettle();
      expect((await store.read()).sampleHistory, isTrue);
      expect(find.text('Meals today'), findsOneWidget);
    });

    testWidgets('the profile form saves and continues to Today', (
      tester,
    ) async {
      final store = await open(tester);
      await tester.tap(find.text('Set up my profile'));
      await tester.pumpAndSettle();
      expect(find.text('Set up your profile'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Height (cm)'),
        '172',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Weight (kg)'),
        '68',
      );
      await tester.pump();
      expect(find.textContaining('BMI 23.0'), findsOneWidget);
      await tester.tap(find.text('Continue to Today'));
      await tester.pumpAndSettle();
      expect((await store.read()).profile!.height, 172);
      expect(find.text('Meals today'), findsOneWidget);
    });

    testWidgets('invalid values are explained and nothing is saved', (
      tester,
    ) async {
      final store = await open(tester);
      await tester.tap(find.text('Set up my profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Height (cm)'),
        '20',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Weight (kg)'),
        '68',
      );
      await tester.tap(find.text('Continue to Today'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 100–250 cm.'), findsOneWidget);
      expect((await store.read()).profile, isNull);
    });

    testWidgets('a target needs the confirmation checkbox', (tester) async {
      await open(tester);
      await tester.tap(find.text('Set up my profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Height (cm)'),
        '172',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Weight (kg)'),
        '68',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Daily target (kcal, optional)'),
        '1800',
      );
      await tester.tap(find.text('Continue to Today'));
      await tester.pumpAndSettle();
      expect(find.text(targetConfirmationMessage), findsOneWidget);
    });
  });
}
