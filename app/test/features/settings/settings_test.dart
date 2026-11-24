import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/app/app.dart';
import 'package:platewise/core/data/core_providers.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/core/data/profile/profile_repositories.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/onboarding/data/onboarding_providers.dart';
import 'package:platewise/features/onboarding/data/onboarding_repositories.dart';
import 'package:platewise/features/settings/data/settings_providers.dart';
import 'package:platewise/features/settings/data/settings_repositories.dart';
import 'package:platewise/features/settings/domain/energy.dart';
import 'package:platewise/features/settings/domain/settings_repository.dart';
import 'package:platewise/features/settings/domain/settings_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

import '../meal_logging/fakes.dart';

const profile = Profile(height: 170, weight: 70, target: 2000);

class FakeSettings implements SettingsRepository {
  final calls = <String>[];
  Object? error;
  @override
  Future<void> setCorrectionConsent(bool enabled) async {
    calls.add('consent:$enabled');
    if (error != null) throw error!;
  }

  @override
  Future<void> submitCorrection(String id, Correction c) async {
    calls.add('correction:$id:${c.food}:${c.grams}');
    if (error != null) throw error!;
  }

  @override
  Future<EnergyEstimate> estimateEnergy(
    Profile p,
    int age,
    String c,
    String a,
  ) async => calculateEnergy(p, age, c, a);

  @override
  Future<void> eraseData({required bool account}) async {
    calls.add('erase:$account');
    if (error != null) throw error!;
  }
}

void main() {
  setUpAll(timezone.initializeTimeZones);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('rules', () {
    test('energy age', () {
      expect(parseEnergyAge('19'), 19);
      expect(parseEnergyAge(' 78 '), 78);
      for (final bad in ['18', '79', '', 'x']) {
        expect(parseEnergyAge(bad), isNull, reason: bad);
      }
    });

    test(
      'the energy estimate uses Mifflin–St Jeor and the activity factor',
      () {
        final e = calculateEnergy(profile, 30, 'plus_5', 'low');
        expect(e.resting, 1618);
        expect(e.total, 1941);
        expect(e.canApply, isTrue);
        expect(
          calculateEnergy(
            const Profile(height: 150, weight: 35, target: null),
            70,
            'minus_161',
            'low',
          ).canApply,
          isFalse,
        );
      },
    );

    test('a correction is checked field by field', () {
      CorrectionResult build(String g, String l, String h) =>
          buildCorrection(food: 'rice', grams: g, low: l, high: h);
      expect(build('150', '180', '220').correction!.range.label, '180–220');
      expect(build('0', '1', '2').error, isNotNull);
      expect(build('150', '-1', '2').error, isNotNull);
      expect(build('150', '1', '7000').error, isNotNull);
      expect(
        build('150', '300', '200').error,
        'The high estimate must be at least the low estimate.',
      );
    });
  });

  group('demo repository', () {
    late DemoStore store;
    late DemoSettingsRepository repo;
    setUp(() {
      store = DemoStore(SharedPreferencesAsync());
      repo = DemoSettingsRepository(store);
    });

    test('consent needs a profile and is saved with it', () async {
      await expectLater(
        repo.setCorrectionConsent(true),
        throwsA(isA<Failure>()),
      );
      await store.update((_) => const Overview(profile: profile));
      await repo.setCorrectionConsent(true);
      expect((await store.read()).profile!.correctionConsent, isTrue);
    });

    test('corrections are not shared from the demo', () async {
      await expectLater(
        repo.submitCorrection('i', (
          food: 'rice',
          grams: 1,
          range: const CalorieRange(1, 2),
        )),
        throwsA(isA<Failure>()),
      );
    });

    test('ages outside the formula are refused', () async {
      await expectLater(
        repo.estimateEnergy(profile, 15, 'plus_5', 'low'),
        throwsA(isA<Failure>()),
      );
      expect(
        (await repo.estimateEnergy(profile, 30, 'plus_5', 'low')).total,
        1941,
      );
    });

    test('erasing clears everything', () async {
      await store.update((_) => const Overview(profile: profile));
      await repo.eraseData(account: false);
      expect((await store.read()).profile, isNull);
    });
  });

  group('screens', () {
    Future<(DemoStore, FakeSettings)> open(
      WidgetTester tester, {
      bool demo = false,
      Profile? who = profile,
    }) async {
      tester.view.physicalSize = const Size(700, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = DemoStore(SharedPreferencesAsync());
      await store.update((_) => Overview(profile: who));
      final rig = Rig(demo: demo);
      rig.overviews.source = store.read;
      final settings = FakeSettings();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            settingsRepositoryProvider.overrideWithValue(settings),
            profileRepositoryProvider.overrideWithValue(
              DemoProfileRepository(store),
            ),
            onboardingRepositoryProvider.overrideWithValue(
              const LiveOnboardingRepository(),
            ),
          ],
          child: const PlateWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings and privacy'));
      await tester.pumpAndSettle();
      return (store, settings);
    }

    testWidgets('shows the profile summary and live-only controls', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Profile & privacy'), findsOneWidget);
      expect(find.text('Daily target 2,000 kcal'), findsOneWidget);
      expect(find.text('Manage account'), findsOneWidget);
      expect(find.text('Allow correction contributions'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('demo mode hides account and sharing', (tester) async {
      await open(tester, demo: true);
      expect(find.text('Manage account'), findsNothing);
      expect(find.text('Allow correction contributions'), findsNothing);
      expect(find.text('Clear demo data'), findsOneWidget);
    });

    testWidgets('consent can be switched on and a correction submitted', (
      tester,
    ) async {
      final (store, settings) = await open(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.calls, ['consent:true']);
      // The fake does not store the flag, so show the link by updating the store.
      await store.update(
        (s) => s.copyWith(profile: profile.copyWith(correctionConsent: true)),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit a food correction'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Portion (g)'),
        '150',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low estimate (kcal)'),
        '180',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'High estimate (kcal)'),
        '220',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(settings.calls.last, 'correction:new-id:rice:150');
      expect(find.text('Correction submitted for review'), findsOneWidget);
    });

    testWidgets('a failing action shows its message', (tester) async {
      final (_, settings) = await open(tester);
      settings.error = const Failure('Could not update.');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Could not update.'), findsOneWidget);
    });

    testWidgets('deleting data asks first, then returns to the start', (
      tester,
    ) async {
      final (_, settings) = await open(tester);
      await tester.tap(find.text('Delete app data'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your app data?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete data'));
      await tester.pumpAndSettle();
      expect(settings.calls, ['erase:false']);
      expect(find.text('Data deleted'), findsOneWidget);
    });

    testWidgets('cancelling a deletion changes nothing', (tester) async {
      final (_, settings) = await open(tester);
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(settings.calls, isEmpty);
    });

    testWidgets(
      'the energy estimate needs its inputs, then can become the target',
      (tester) async {
        final (store, _) = await open(tester);
        await tester.tap(find.text('Estimate adult energy needs'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Calculate estimate'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(TextField, 'Age in years'),
          '30',
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Male study group (+5)').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mostly seated').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Calculate estimate'));
        await tester.pumpAndSettle();
        expect(find.text('1,941 kcal'), findsOneWidget);
        await tester.tap(find.text('Review as a daily target'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm target'));
        await tester.pumpAndSettle();
        expect((await store.read()).profile!.target, 1941);
        expect(find.text('Daily target updated'), findsOneWidget);
      },
    );

    testWidgets('credits list the team', (tester) async {
      await open(tester);
      await tester.tap(find.text('Credits and licenses'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Flutter development'), findsOneWidget);
    });
  });
}

typedef CorrectionResult = ({Correction? correction, String? error});
