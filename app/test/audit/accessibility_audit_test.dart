import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/app/app.dart';
import 'package:platewise/app/composition.dart';
import 'package:platewise/app/router.dart';
import 'package:platewise/core/config/app_config.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/features/onboarding/data/onboarding_repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

/// An accessibility audit of the whole demo app, on a phone-sized screen at
/// normal and doubled text size. It renders every screen, and the states that
/// need a few taps, then checks Flutter's tap-target, labeling and contrast
/// guidelines and looks for layout overflow. Any finding fails the test, so a
/// regression cannot slip in.
///
/// It checks what Flutter can measure. It does not replace testing with a
/// screen reader, switch control or real devices.

/// Every screen reachable by path, as a person with a sample week of data
/// sees it. The welcome screen is shown to a new person with no data.
const screens = {
  'welcome (new person)': '/welcome',
  'today': '/today',
  'decide': '/decide',
  'nearby': '/nearby',
  'progress': '/progress',
  'log a meal': '/log',
  'water': '/water',
  'profile': '/profile',
  'settings': '/settings',
  'energy estimate': '/energy',
  'credits': '/credits',
  'correction': '/correction',
  'account': '/account',
};

/// States that need a few taps from the log-a-meal screen.
final journeys = <String, Future<void> Function(WidgetTester)>{
  'review a meal manually': (tester) async {
    await tap(tester, 'Enter meal manually');
  },
  'review with the food editor open': (tester) async {
    await tap(tester, 'Enter meal manually');
    await tap(tester, 'Add food');
  },
  'review the sample photo estimate': (tester) async {
    await tap(tester, 'Review sample photo estimate');
  },
  'voice entry': (tester) async {
    await tap(tester, 'Voice');
  },
  'typed entry': (tester) async {
    await tap(tester, 'Text');
  },
};

final guidelines = {
  'Android tap target (48 dp)': androidTapTargetGuideline,
  'iOS tap target (44 pt)': iOSTapTargetGuideline,
  'labeled tap targets': labeledTapTargetGuideline,
  'text contrast': textContrastGuideline,
};

Future<void> tap(WidgetTester tester, String text) async {
  // Doubled text pushes buttons below the fold, so scroll to them first.
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> open(
  WidgetTester tester,
  String path, {
  required double textScale,
  required bool sample,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final preferences = SharedPreferencesAsync();
  if (sample) {
    await DemoOnboardingRepository(DemoStore(preferences)).startSampleDay();
  }
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final overrides = await composeOverrides(
    const AppConfig(mode: 'demo'),
    preferences: preferences,
  );
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const PlateWiseApp()),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(MaterialApp));
  ProviderScope.containerOf(context).read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

/// Runs every check on what is on screen and returns what failed.
Future<List<String>> audit(WidgetTester tester, String label) async {
  final findings = <String>[];
  final thrown = tester.takeException();
  if (thrown != null) {
    findings.add('$label: ${thrown.toString().split('\n').first}');
  }
  for (final guideline in guidelines.entries) {
    final result = await guideline.value.evaluate(tester);
    if (!result.passed) {
      final reason = result.reason?.split('\n').take(3).join(' | ');
      findings.add('$label: ${guideline.key}: $reason');
    }
  }
  return findings;
}

void main() {
  setUpAll(timezone.initializeTimeZones);

  for (final scale in [1.0, 2.0]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} at ${scale}x text', (tester) async {
        final handle = tester.ensureSemantics();
        await open(
          tester,
          entry.value,
          textScale: scale,
          sample: entry.value != '/welcome',
        );
        expect(await audit(tester, '${entry.key} @${scale}x'), isEmpty);
        handle.dispose();
      });
    }
    for (final entry in journeys.entries) {
      testWidgets('${entry.key} at ${scale}x text', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, '/log', textScale: scale, sample: true);
        await entry.value(tester);
        expect(await audit(tester, '${entry.key} @${scale}x'), isEmpty);
        handle.dispose();
      });
    }
  }

  testWidgets('the checks do catch a problem', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Semantics(
              button: true,
              label: 'tiny',
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(width: 16, height: 16),
              ),
            ),
          ),
        ),
      ),
    );
    final result = await androidTapTargetGuideline.evaluate(tester);
    expect(result.passed, isFalse);
    handle.dispose();
  });
}
