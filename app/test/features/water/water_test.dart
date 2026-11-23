import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/app/app.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/today/data/today_providers.dart';
import 'package:platewise/features/today/data/today_repositories.dart';
import 'package:platewise/features/water/data/water_providers.dart';
import 'package:platewise/features/water/data/water_repositories.dart';
import 'package:platewise/features/water/domain/water_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

import '../meal_logging/fakes.dart';

void main() {
  setUpAll(timezone.initializeTimeZones);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('amounts are whole millilitres from 1 to 2,000', () {
    expect(parseWaterAmount(' 250 '), 250);
    expect(parseWaterAmount('2000'), 2000);
    for (final bad in ['', '0', '2001', '1.5', 'x']) {
      expect(parseWaterAmount(bad), isNull, reason: bad);
    }
  });

  group('demo repository', () {
    late DemoStore store;
    late DemoWaterRepository repo;
    setUp(() {
      store = DemoStore(SharedPreferencesAsync());
      repo = DemoWaterRepository(store);
    });

    test('saving the same new id twice keeps one entry', () async {
      final first = await repo.save('w', 250);
      final again = await repo.save('w', 250);
      expect((await store.read()).water, hasLength(1));
      expect(again.revision, first.revision);
    });

    test('an edit needs the current revision', () async {
      final entry = await repo.save('w', 250);
      final edited = await repo.save('w', 400, revision: entry.revision);
      expect(edited.amount, 400);
      expect(edited.at, entry.at);
      await expectLater(
        repo.save('w', 500, revision: 'stale'),
        throwsA(isA<Failure>()),
      );
    });

    test('a removed entry cannot come back', () async {
      await repo.save('w', 250);
      await repo.remove('w');
      expect((await store.read()).water, isEmpty);
      await expectLater(repo.save('w', 250), throwsA(isA<Failure>()));
    });

    test('out of range amounts are refused', () async {
      await expectLater(repo.save('w', 0), throwsA(isA<Failure>()));
      await expectLater(repo.save('w', 2001), throwsA(isA<Failure>()));
    });
  });

  group('on Today', () {
    Future<DemoStore> open(
      WidgetTester tester, {
      List<WaterEntry> water = const [],
    }) async {
      tester.view.physicalSize = const Size(700, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = DemoStore(SharedPreferencesAsync());
      await store.update(
        (_) => Overview(
          profile: const Profile(height: 170, weight: 70, target: 2000),
          water: water,
        ),
      );
      final rig = Rig();
      rig.overviews.source = store.read;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            waterRepositoryProvider.overrideWithValue(
              DemoWaterRepository(store),
            ),
            todayRepositoryProvider.overrideWithValue(
              DemoTodayRepository(store),
            ),
          ],
          child: const PlateWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('quick add shows the total, adds and offers undo', (
      tester,
    ) async {
      final store = await open(tester);
      expect(find.text('0 / 2,000 ml'), findsOneWidget);
      await tester.tap(find.text('+250 ml'));
      await tester.pumpAndSettle();
      expect(find.text('Added 250 ml'), findsOneWidget);
      expect((await store.read()).water.single.amount, 250);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((await store.read()).water, isEmpty);
    });

    testWidgets('the arrow opens the water log, which can edit and remove', (
      tester,
    ) async {
      final store = await open(tester);
      await tester.tap(find.text('+500 ml'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open water log'));
      await tester.pumpAndSettle();
      expect(find.text('Water log'), findsOneWidget);
      expect(find.text('500 ml'), findsOneWidget);

      await tester.tap(find.byTooltip('Water entry actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit amount'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '350');
      await tester.tap(find.text('Save water'));
      await tester.pumpAndSettle();
      expect((await store.read()).water.single.amount, 350);

      await tester.tap(find.byTooltip('Water entry actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove entry'));
      await tester.pumpAndSettle();
      expect((await store.read()).water, isEmpty);
      expect(find.text('No water logged yet'), findsOneWidget);
    });

    testWidgets('a custom amount is validated', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Open water log'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '5000');
      await tester.tap(find.text('Save water'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 1–2000 ml.'), findsOneWidget);
    });
  });
}
