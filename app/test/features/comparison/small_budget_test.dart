import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/presentation/session_state.dart';
import 'package:platewise/core/theme/plate_theme.dart';
import 'package:platewise/features/comparison/data/comparison_providers.dart';
import 'package:platewise/features/comparison/domain/decision.dart';
import 'package:platewise/features/comparison/presentation/decide_controller.dart';
import 'package:platewise/features/comparison/presentation/decide_screen.dart';
import 'package:platewise/features/comparison/presentation/menu_review_args.dart';
import 'package:platewise/features/comparison/presentation/menu_review_screen.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

import '../meal_logging/fakes.dart';
import 'comparison_test.dart' show FakeComparison;

/// An overview with a 2,000 kcal target and [logged] kcal already eaten today.
Overview day({int logged = 0}) => Overview(
  profile: const Profile(height: 170, weight: 70, target: 2000),
  targets: const [TargetSnapshot('2026-01-01', 2000)],
  localDay: DateTime.utc(2026, 6, 1),
  meals: logged == 0
      ? const []
      : [
          SavedMeal(
            draftOf([rice]),
            DateTime.utc(2026, 6, 1, 6),
            'rev',
            logged,
          ),
        ],
);

void main() {
  setUpAll(timezone.initializeTimeZones);

  group('the rule', () {
    test('a budget is small only below the minimum', () {
      expect(isSmallBudget(null), isFalse);
      expect(isSmallBudget(1), isTrue);
      expect(isSmallBudget(minPlannableBudget - 1), isTrue);
      expect(isSmallBudget(minPlannableBudget), isFalse);
      expect(isSmallBudget(2000), isFalse);
    });

    test('the wording describes what is possible and never urges less', () {
      for (final text in [planBudgetTooSmallMessage, smallBudgetNote]) {
        expect(
          text,
          isNot(
            matches(RegExp(r'skip|fast|starve|less', caseSensitive: false)),
          ),
        );
        expect(text, contains('compare'));
      }
      expect(
        planBudgetTooSmallMessage,
        contains('qualified healthcare professional'),
      );
      expect(planBudgetTooSmallMessage, contains('$minPlannableBudget kcal'));
    });

    test('the backend uses the same minimum', () {
      final source = File('../supabase/functions/domain/contracts.ts')
          .readAsStringSync();
      final match = RegExp(r'minPlannableBudget\s*=\s*(\d+)')
          .firstMatch(source);
      expect(match, isNotNull);
      expect(int.parse(match!.group(1)!), minPlannableBudget);
    });
  });

  group('planning a dish', () {
    ProviderContainer open(Rig rig, FakeComparison comparison) {
      final container = ProviderContainer(
        overrides: [
          ...rig.overrides,
          comparisonRepositoryProvider.overrideWithValue(comparison),
        ],
      );
      addTearDown(container.dispose);
      container.listen(decideControllerProvider, (_, _) {});
      return container;
    }

    test(
      'a typed budget below the minimum is refused before any request',
      () async {
        final comparison = FakeComparison();
        final c = open(Rig(overview: day()), comparison);
        final controller = c.read(decideControllerProvider.notifier)
          ..toggleBudgetMode()
          ..setBudgetText('${minPlannableBudget - 1}')
          ..setDishText('Vegetable khichuri');
        await controller.recommendDish();
        final state = c.read(decideControllerProvider);
        expect(state.recommendationError, planBudgetTooSmallMessage);
        expect(state.recommendationBusy, isFalse);
        expect(state.recommendation, isNull);
        expect(comparison.recommendations, isEmpty);
      },
    );

    test('the minimum itself is sent on', () async {
      final comparison = FakeComparison()
        ..recommendation = const DishRecommendation(
          portion: 'Two spoons',
          adjustments: [],
          range: CalorieRange(90, 140),
          confidence: Confidence.medium,
          assumptions: [],
        );
      final c = open(Rig(overview: day()), comparison);
      final controller = c.read(decideControllerProvider.notifier)
        ..toggleBudgetMode()
        ..setBudgetText('$minPlannableBudget')
        ..setDishText('Vegetable khichuri');
      await controller.recommendDish();
      expect(comparison.recommendations.single.budget, minPlannableBudget);
      expect(
        c.read(decideControllerProvider).recommendation?.portion,
        'Two spoons',
      );
    });

    test('a small amount left of the day is refused too', () async {
      final comparison = FakeComparison();
      final c = open(Rig(overview: day(logged: 1900)), comparison);
      await c.read(overviewProvider.future);
      final controller = c.read(decideControllerProvider.notifier)
        ..setDishText('Vegetable khichuri');
      await controller.recommendDish();
      expect(
        c.read(decideControllerProvider).recommendationError,
        planBudgetTooSmallMessage,
      );
      expect(comparison.recommendations, isEmpty);
    });
  });

  group('screens', () {
    Future<FakeComparison> show(
      WidgetTester tester,
      Rig rig,
      Widget screen,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final comparison = FakeComparison();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            comparisonRepositoryProvider.overrideWithValue(comparison),
          ],
          child: MaterialApp(
            theme: plateTheme(),
            home: Scaffold(body: screen),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return comparison;
    }

    testWidgets(
      'Decide explains a small budget and still lets people compare',
      (tester) async {
        await show(
          tester,
          Rig(overview: day(logged: 1900)),
          const DecideScreen(),
        );
        expect(find.text('100 kcal remaining today'), findsOneWidget);
        expect(find.text(smallBudgetNote), findsOneWidget);
      },
    );

    testWidgets(
      'a typed small budget shows the note, and a normal one does not',
      (tester) async {
        await show(tester, Rig(overview: day()), const DecideScreen());
        expect(find.text(smallBudgetNote), findsNothing);
        await tester.tap(find.text('Set a meal budget'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Meal budget (kcal)'),
          '30',
        );
        await tester.pump();
        expect(find.text(smallBudgetNote), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Meal budget (kcal)'),
          '600',
        );
        await tester.pump();
        expect(find.text(smallBudgetNote), findsNothing);
      },
    );

    testWidgets(
      'planning with a small budget shows the explanation, not a suggestion',
      (tester) async {
        final comparison = await show(
          tester,
          Rig(overview: day(logged: 1900)),
          const DecideScreen(),
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Dish you plan to cook'),
          'Vegetable khichuri',
        );
        await tester.ensureVisible(find.text('Suggest a portion'));
        await tester.tap(find.text('Suggest a portion'));
        await tester.pumpAndSettle();
        expect(find.text(planBudgetTooSmallMessage), findsOneWidget);
        expect(find.text('Suggested portion'), findsNothing);
        expect(comparison.recommendations, isEmpty);
      },
    );

    testWidgets('menu review shows the note for a small budget only', (
      tester,
    ) async {
      await show(
        tester,
        Rig(overview: day()),
        const MenuReviewScreen(
          MenuReviewArgs([MenuOption('Dal'), MenuOption('Rice')], 80),
        ),
      );
      expect(find.text(smallBudgetNote), findsOneWidget);
      await show(
        tester,
        Rig(overview: day()),
        const MenuReviewScreen(
          MenuReviewArgs([MenuOption('Dal'), MenuOption('Rice')], 500),
        ),
      );
      expect(find.text(smallBudgetNote), findsNothing);
    });
  });
}
