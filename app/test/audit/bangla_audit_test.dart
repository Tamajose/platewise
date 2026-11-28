import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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

/// Opens every screen in Bangla and checks three things: no screen throws or
/// overflows at normal and doubled text size, no English words are left on it,
/// and no Latin digit is shown. Names of people, products and units that are
/// written in Latin script on purpose are listed in [allowed].
const screens = {
  'welcome': '/welcome',
  'today': '/today',
  'decide': '/decide',
  'nearby': '/nearby',
  'progress': '/progress',
  'log a meal': '/log',
  'water': '/water',
  'profile edit': '/profile',
  'profile page': '/me',
  'settings': '/settings',
  'export': '/export',
  'energy estimate': '/energy',
  'credits': '/credits',
  'correction': '/correction',
  'account': '/account',
};

/// Latin-script words that are meant to stay: brand and product names, the
/// names of fonts and licences, and file formats.
final allowed = RegExp(
  r'PlateWise|Supabase|OpenAI|OpenStreetMap|Inter|Noto|Sans|Bengali|SIL|Open|Font|License|CSV|IANA|JPEG|PNG|WebP|HTTPS|localhost|'
  r'JSON|POST|WebM|WAV|M4A|MB|AI|UX|Asia|Dhaka|Flutter|Mifflin|Jeor|OSM|URL|ID|English',
);

Future<void> open(
  WidgetTester tester,
  String path, {
  required double textScale,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final preferences = SharedPreferencesAsync();
  await preferences.setString('platewise.language', 'bn');
  if (path != '/welcome') {
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

/// The text a person can read on screen, including tooltips.
List<String> visibleText(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (text.data != null) text.data!,
  for (final button in tester.widgetList<IconButton>(find.byType(IconButton)))
    if (button.tooltip != null) button.tooltip!,
];

/// English left on screen: a run of three or more Latin letters that is not
/// an allowed name.
List<String> leftovers(List<String> shown) => [
  for (final text in shown)
    if (RegExp(r'[A-Za-z]{3,}').hasMatch(text.replaceAll(allowed, ''))) text,
];

void main() {
  setUpAll(() async {
    timezone.initializeTimeZones();
    await initializeDateFormatting('bn');
  });

  for (final scale in [1.0, 2.0]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} in Bangla at ${scale}x text', (tester) async {
        await open(tester, entry.value, textScale: scale);
        final thrown = tester.takeException();
        expect(thrown, isNull, reason: '${entry.key}: $thrown');
        final shown = visibleText(tester);
        expect(shown, isNotEmpty);
        if (scale == 1.0) {
          expect(
            leftovers(shown),
            isEmpty,
            reason:
                '${entry.key} still shows English: ${leftovers(shown).join(' | ')}',
          );
          expect(
            shown.where((t) => RegExp('[0-9]').hasMatch(t)),
            isEmpty,
            reason: '${entry.key} shows Latin digits',
          );
        }
      });
    }
  }
}
