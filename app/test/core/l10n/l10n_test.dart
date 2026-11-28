import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/core/l10n/l10n.dart';
import 'package:platewise/core/l10n/bn_catalogue.dart';
import 'package:platewise/core/l10n/digits.dart';
import 'package:platewise/core/l10n/language_providers.dart';
import 'package:platewise/core/l10n/translate.dart';
import 'package:platewise/core/widgets/widgets.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

List<String> placeholders(String text) =>
    RegExp(r'\{p\d+\}').allMatches(text).map((m) => m.group(0)!).toList()
      ..sort();

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('digits', () {
    test('every digit becomes its Bangla form and other text is kept', () {
      expect(toBanglaDigits('0123456789'), '০১২৩৪৫৬৭৮৯');
      expect(toBanglaDigits('1,200–5,000 kcal'), '১,২০০–৫,০০০ kcal');
    });
  });

  group('translate', () {
    test('English is returned as it is, with values filled in', () {
      expect(translate(AppLanguage.en, 'Today'), 'Today');
      expect(
        translate(AppLanguage.en, 'Last {p0} days', {'p0': 30}),
        'Last 30 days',
      );
    });

    test(
      'Bangla uses the catalogue, fills values and writes Bangla digits',
      () {
        expect(translate(AppLanguage.bn, 'Today'), 'আজ');
        expect(
          translate(AppLanguage.bn, 'Last {p0} days', {'p0': 30}),
          'সর্বশেষ ৩০ দিন',
        );
      },
    );

    test('text with no entry stays in English instead of failing', () {
      expect(translate(AppLanguage.bn, 'Something new'), 'Something new');
    });

    test('a message built with its values already in is still translated', () {
      expect(
        translate(AppLanguage.bn, 'You logged meals on 4 of 7 days.'),
        'আপনি ৭ দিনের মধ্যে ৪ দিন খাবার নথিভুক্ত করেছেন।',
      );
    });

    test('numbers carry separators in either language', () {
      expect(formatNumber(AppLanguage.en, 2000), '2,000');
      expect(formatNumber(AppLanguage.bn, 2000), '২,০০০');
    });
  });

  group('the Bangla catalogue', () {
    test(
      'every entry keeps the values of the English text and is not empty',
      () {
        final broken = [
          for (final entry in bnCatalogue.entries)
            if (entry.value.trim().isEmpty ||
                placeholders(entry.key).toString() !=
                    placeholders(entry.value).toString())
              entry.key,
        ];
        expect(broken, isEmpty);
      },
    );

    test('safety wording is present and neutral', () {
      final target = bnCatalogue.entries.firstWhere(
        (e) => e.key.startsWith('This pilot accepts 1,200'),
      );
      expect(target.value, contains('স্বাস্থ্যসেবা পেশাদার'));
      for (final value in bnCatalogue.values) {
        expect(value, isNot(contains('না খেয়ে')));
      }
    });
  });

  group('the language choice', () {
    test('starts in English, switches and is remembered', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(appLanguageProvider), AppLanguage.en);
      await container.read(appLanguageProvider.notifier).set(AppLanguage.bn);
      expect(container.read(appLanguageProvider), AppLanguage.bn);
      final next = ProviderContainer();
      addTearDown(next.dispose);
      next.read(appLanguageProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(next.read(appLanguageProvider), AppLanguage.bn);
    });

    testWidgets('the toggle changes the words on screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final language = ref.watch(appLanguageProvider);
              return MaterialApp(
                locale: language.locale,
                supportedLocales: [
                  for (final l in AppLanguage.values) l.locale,
                ],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: Scaffold(
                  body: Column(
                    children: [
                      const LanguageToggle(),
                      Builder(builder: (context) => Text(context.tr('Today'))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.text('বাংলা'));
      await tester.pumpAndSettle();
      expect(find.text('আজ'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
    });
  });
}
