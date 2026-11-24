import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:platewise/core/data/api/api_client.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:platewise/core/presentation/review_args.dart';
import 'package:platewise/core/presentation/routes.dart';
import 'package:platewise/core/presentation/session_state.dart';
import 'package:platewise/core/theme/plate_theme.dart';
import 'package:platewise/features/comparison/data/comparison_providers.dart';
import 'package:platewise/features/comparison/data/demo_comparison_repository.dart';
import 'package:platewise/features/comparison/data/live_comparison_repository.dart';
import 'package:platewise/features/comparison/domain/compare_photos.dart';
import 'package:platewise/features/comparison/domain/comparison_repository.dart';
import 'package:platewise/features/comparison/domain/decision.dart';
import 'package:platewise/features/comparison/presentation/decide_controller.dart';
import 'package:platewise/features/comparison/presentation/decide_screen.dart';
import 'package:platewise/features/comparison/presentation/menu_review_args.dart';
import 'package:platewise/features/comparison/presentation/menu_review_screen.dart';

import '../meal_logging/fakes.dart';

class FakeComparison implements ComparisonRepository {
  final compared = <List<DecisionOption>>[];
  Object? compareError, estimateError, recommendationError;
  DishRecommendation recommendation = const DishRecommendation(
    portion: 'One small bowl',
    adjustments: ['Use less oil'],
    range: CalorieRange(300, 450),
    confidence: Confidence.medium,
    assumptions: ['Prepared with moderate oil'],
  );
  final recommendations = <({String dish, String language, int budget})>[];
  Completer<DishRecommendation>? recommendationGate;
  List<RankedMeal> ranked = [];
  List<DecisionFailure> failures = [];

  @override
  Future<DecisionResult> compare(
    List<DecisionOption> options,
    int? budget,
  ) async {
    compared.add(options);
    if (compareError != null) throw compareError!;
    return DecisionResult(ranked, failures);
  }

  @override
  Future<MealDraft> estimatePhoto(String? imagePath) async {
    if (estimateError != null) throw estimateError!;
    return draftOf([rice]);
  }

  @override
  Future<DishRecommendation> recommendDish(
    String dish,
    String language,
    int budget,
  ) async {
    recommendations.add((dish: dish, language: language, budget: budget));
    if (recommendationError != null) throw recommendationError!;
    return recommendationGate?.future ?? recommendation;
  }

  @override
  Future<List<MenuOption>> extractMenu(String? imagePath) async => const [
    MenuOption('Dal'),
  ];

  @override
  List<MenuOption>? sampleMenu() => null;
}

RankedMeal rank(String key, int n) =>
    RankedMeal(key, draftOf([rice], id: 'r$n'), n, BudgetFit.fits, 'ok');

Uint8List photo() => Uint8List.fromList([1]);

void main() {
  setUpAll(timezone.initializeTimeZones);
  group('budget input', () {
    test('blank is no budget, numbers must be 1 to 5,000', () {
      expect(parseMealBudget('  '), isNull);
      expect(parseMealBudget('650'), 650);
      for (final bad in ['0', '5001', 'abc', '1.5']) {
        expect(
          () => parseMealBudget(bad),
          throwsA(isA<Failure>()),
          reason: bad,
        );
      }
    });

    test('the suggestion is what is left of today\'s target', () {
      expect(suggestedBudget(null), isNull);
      expect(suggestedBudget(const Overview()), isNull);
      final overview = Overview(
        profile: const Profile(height: 170, weight: 70, target: 2000),
        targets: const [TargetSnapshot('2026-01-01', 2000)],
        localDay: DateTime.utc(2026, 6, 1),
      );
      expect(suggestedBudget(overview), 2000);
    });

    test('dish fields are checked', () {
      expect(
        buildMenuOption(name: ' ', portion: '', kcal: '').error,
        isNotNull,
      );
      expect(
        buildMenuOption(name: 'a', portion: '', kcal: '10').error,
        isNotNull,
      );
      final ok = buildMenuOption(
        name: ' Dal ',
        portion: ' bowl ',
        kcal: '300',
      ).dish!;
      expect((ok.name, ok.portion, ok.kcal), ('Dal', 'bowl', 300));
      expect(
        buildMenuOption(name: 'a', portion: ' ', kcal: '').dish!.portion,
        isNull,
      );
    });
  });

  group('comparing photos', () {
    late FakeComparison comparison;
    late FakeMedia media;
    late ComparePhotos run;
    setUp(() {
      comparison = FakeComparison();
      media = FakeMedia();
      run = ComparePhotos(comparison, media);
    });

    test('two photos are uploaded and ranked together', () async {
      comparison.ranked = [rank('0', 1), rank('1', 2)];
      final paths = <String?>[null, null];
      final result = await run(
        photos: [photo(), photo()],
        paths: paths,
        budget: 500,
      );
      expect(media.uploads, hasLength(2));
      expect(paths, ['u/photo.jpg', 'u/photo.jpg']);
      expect(result.meals, hasLength(2));
      expect(comparison.compared.single.map((o) => o.key), ['0', '1']);
    });

    test('an already uploaded photo is not uploaded again', () async {
      comparison.ranked = [rank('0', 1), rank('1', 2)];
      await run(
        photos: [photo(), photo()],
        paths: ['kept', null],
        budget: null,
      );
      expect(media.uploads, hasLength(1));
      expect(comparison.compared.single.first.path, 'kept');
    });

    test('one failed upload leaves one estimate and a failure', () async {
      var calls = 0;
      final failing = _FlakyMedia(() => ++calls == 1);
      final result = await ComparePhotos(comparison, failing)(
        photos: [photo(), photo()],
        paths: [null, null],
        budget: 5000,
      );
      expect(result.meals, hasLength(1));
      expect(result.meals.single.rank, 1);
      expect(result.failures, hasLength(1));
      expect(comparison.compared, isEmpty);
    });

    test('a failed single estimate is reported, not thrown', () async {
      final failing = _FlakyMedia(() => false);
      comparison.estimateError = const Failure('Busy.');
      final result = await ComparePhotos(comparison, failing)(
        photos: [photo(), null],
        paths: [null, null],
        budget: null,
      );
      expect(result.meals, isEmpty);
      expect(result.failures.single.message, 'Busy.');
    });

    test('a whole-call failure propagates but uploads stay recorded', () async {
      comparison.compareError = const Failure('Down.');
      final paths = <String?>[null, null];
      await expectLater(
        run(photos: [photo(), photo()], paths: paths, budget: null),
        throwsA(isA<Failure>()),
      );
      expect(paths.nonNulls, hasLength(2));
    });

    test('photos uploaded after the screen closed are deleted', () async {
      final paths = <String?>[null, null];
      final result = await run(
        photos: [photo(), photo()],
        paths: paths,
        budget: null,
        isOpen: () => false,
      );
      expect(media.discarded, hasLength(2));
      expect(paths, [null, null]);
      expect(result.meals, isEmpty);
    });

    test('demo mode cannot analyse photos', () async {
      media.path = null;
      final result = await run(
        photos: [photo(), photo()],
        paths: [null, null],
        budget: null,
      );
      expect(result.failures, hasLength(2));
      expect(result.failures.first.message, contains('demo mode'));
    });
  });

  group('demo comparison', () {
    final repo = DemoComparisonRepository(generateId: () => 'id');

    test('ranks dishes that fit the budget first', () async {
      final result = await repo.compare([
        const DecisionOption.menu('0', MenuOption('Chicken biryani')),
        const DecisionOption.menu('1', MenuOption('Rice')),
      ], 300);
      expect(result.meals.map((m) => m.key), ['1', '0']);
      expect(result.meals.first.fit, BudgetFit.fits);
      expect(result.meals.last.fit, BudgetFit.above);
      expect(result.meals.map((m) => m.rank), [1, 2]);
    });

    test('a printed calorie value is used as given', () async {
      final result = await repo.compare([
        const DecisionOption.menu('0', MenuOption('Mystery', kcal: 420)),
        const DecisionOption.menu('1', MenuOption('Rice')),
      ], null);
      final mystery = result.meals.firstWhere((m) => m.key == '0');
      expect(mystery.draft.range.label, '420');
      expect(mystery.draft.confidence, Confidence.medium);
    });

    test(
      'an unknown dish and a photo option are reported as failures',
      () async {
        final result = await repo.compare([
          const DecisionOption.menu('0', MenuOption('Sushi')),
          const DecisionOption.photo('1', 'p'),
          const DecisionOption.menu('2', MenuOption('Rice')),
        ], null);
        expect(result.meals.single.key, '2');
        expect(result.failures.map((f) => f.key), ['0', '1']);
      },
    );

    test('has a sample menu and no scanning', () async {
      expect(repo.sampleMenu(), hasLength(3));
      await expectLater(repo.extractMenu('x'), throwsA(isA<Failure>()));
      await expectLater(repo.estimatePhoto('x'), throwsA(isA<Failure>()));
    });
  });

  group('live comparison', () {
    test('sends a planned dish and maps the budget-bounded response', () async {
      late Map<String, Object?> body;
      final api = ApiClient(
        endpoint: apiEndpoint('https://abc.supabase.co'),
        publishableKey: 'k',
        bearer: () async => 't',
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'version': 1,
              'ok': true,
              'data': {
                'portion': 'One small bowl',
                'adjustments': ['Use less oil'],
                'calorie_low': 300,
                'calorie_high': 450,
                'confidence': 'medium',
                'assumptions': ['Prepared with moderate oil'],
              },
            }),
            200,
          );
        }),
      );
      final result = await LiveComparisonRepository(api)
          .recommendDish('Vegetable curry', 'en', 500);
      expect(body['action'], 'recommend_dish');
      expect(body['input'], {
        'dish': 'Vegetable curry',
        'language': 'en',
        'budget': 500,
      });
      expect(result.range.low, 300);
      expect(result.range.high, 450);
      expect(result.adjustments, ['Use less oil']);
    });

    test('rejects a recommendation above the requested budget', () async {
      final api = ApiClient(
        endpoint: apiEndpoint('https://abc.supabase.co'),
        publishableKey: 'k',
        bearer: () async => 't',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'version': 1,
              'ok': true,
              'data': {
                'portion': 'One bowl',
                'adjustments': <String>[],
                'calorie_low': 300,
                'calorie_high': 600,
                'confidence': 'medium',
                'assumptions': <String>[],
              },
            }),
            200,
          ),
        ),
      );
      await expectLater(
        LiveComparisonRepository(api).recommendDish('Curry', 'en', 500),
        throwsA(isA<Failure>()),
      );
    });

    test('sends options and maps ranked results', () async {
      late Map<String, Object?> body;
      final api = ApiClient(
        endpoint: apiEndpoint('https://abc.supabase.co'),
        publishableKey: 'k',
        bearer: () async => 't',
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'version': 1,
              'ok': true,
              'data': {
                'results': [
                  {
                    'key': '0',
                    'rank': 1,
                    'fit': 'no_budget',
                    'reason': 'Set a meal budget to check fit.',
                    'image_storage_path': null,
                    'estimate': {
                      'items': [
                        {
                          'name': 'Dal',
                          'quantity': 1,
                          'unit': 'bowl',
                          'calorie_low': 140,
                          'calorie_high': 220,
                        },
                      ],
                    },
                  },
                ],
                'failures': [
                  {'key': '1', 'message': 'No luck.', 'retryable': true},
                ],
              },
            }),
            200,
          );
        }),
      );
      final result = await LiveComparisonRepository(api, generateId: () => 'g')
          .compare([
            const DecisionOption.menu(
              '0',
              MenuOption('Dal', kcal: 200),
              language: 'bn',
            ),
            const DecisionOption.menu('1', MenuOption('Rice')),
          ], null);
      final input = (body['input']! as Map)['options'] as List;
      expect(input.first, {
        'kind': 'menu',
        'key': '0',
        'name': 'Dal',
        'portion': null,
        'printed_kcal': 200,
        'language': 'bn',
      });
      expect(result.meals.single.fit, BudgetFit.noBudget);
      expect(result.meals.single.draft.source, MealSource.menu);
      expect(result.meals.single.draft.id, 'g');
      expect(result.failures.single.retryable, isTrue);
    });
  });

  group('decide controller', () {
    ProviderContainer open(Rig rig, FakeComparison comparison) {
      final container = ProviderContainer(
        overrides: [
          ...rig.overrides,
          overviewProvider.overrideWith((ref) async => rig.overviews.value),
          comparisonRepositoryProvider.overrideWithValue(comparison),
        ],
      );
      addTearDown(container.dispose);
      container.listen(decideControllerProvider, (_, _) {});
      return container;
    }

    Future<void> twoPhotos(ProviderContainer c) async {
      final controller = c.read(decideControllerProvider.notifier);
      await controller.pickPhoto(0, PhotoSource.gallery);
      await controller.pickPhoto(1, PhotoSource.gallery);
    }

    test('planning validates the dish and selected budget', () async {
      final comparison = FakeComparison();
      final c = open(Rig(), comparison);
      final controller = c.read(decideControllerProvider.notifier);
      await controller.recommendDish();
      expect(
        c.read(decideControllerProvider).recommendationError,
        'Enter the dish you plan to cook.',
      );
      controller.setDishText('Vegetable curry');
      await controller.recommendDish();
      expect(
        c.read(decideControllerProvider).recommendationError,
        'Set a positive meal budget before planning a dish.',
      );
      expect(comparison.recommendations, isEmpty);
    });

    test(
      'planning uses the selected remaining budget and never logs',
      () async {
        final rig = Rig(
          overview: Overview(
            profile: const Profile(height: 170, weight: 70, target: 2000),
            targets: const [TargetSnapshot('2026-01-01', 2000)],
            localDay: DateTime.utc(2026, 6, 1),
          ),
        );
        final comparison = FakeComparison();
        final c = open(rig, comparison);
        await c.read(overviewProvider.future);
        final controller = c.read(decideControllerProvider.notifier)
          ..setDishText('Vegetable curry');
        await controller.recommendDish();
        final state = c.read(decideControllerProvider);
        expect(comparison.recommendations.single, (
          dish: 'Vegetable curry',
          language: 'en',
          budget: 2000,
        ));
        expect(state.recommendation?.range.high, lessThanOrEqualTo(2000));
        expect(state.recommendationBudget, 2000);
        expect(rig.meals.saved, isEmpty);
      },
    );

    test(
      'planning discards a result when its inputs change in flight',
      () async {
        final comparison = FakeComparison()
          ..recommendationGate = Completer<DishRecommendation>();
        final c = open(Rig(), comparison);
        final controller = c.read(decideControllerProvider.notifier)
          ..toggleBudgetMode()
          ..setBudgetText('500')
          ..setDishText('Vegetable curry');
        final pending = controller.recommendDish();
        controller.setDishText('Another curry');
        comparison.recommendationGate!.complete(comparison.recommendation);
        await pending;
        final state = c.read(decideControllerProvider);
        expect(state.recommendation, isNull);
        expect(state.recommendationBusy, isFalse);
      },
    );

    test(
      'planning uses manually selected budget and clears stale output',
      () async {
        final comparison = FakeComparison();
        final c = open(Rig(), comparison);
        final controller = c.read(decideControllerProvider.notifier)
          ..toggleBudgetMode()
          ..setBudgetText('500')
          ..setDishText('Vegetable curry');
        await controller.recommendDish();
        expect(comparison.recommendations.single.budget, 500);
        controller.setBudgetText('700');
        expect(c.read(decideControllerProvider).recommendation, isNull);
      },
    );

    test('an over-budget fake response is never shown', () async {
      final comparison = FakeComparison()
        ..recommendation = const DishRecommendation(
          portion: 'One bowl',
          adjustments: [],
          range: CalorieRange(300, 600),
          confidence: Confidence.medium,
          assumptions: [],
        );
      final c = open(Rig(), comparison);
      final controller = c.read(decideControllerProvider.notifier)
        ..toggleBudgetMode()
        ..setBudgetText('500')
        ..setDishText('Curry');
      await controller.recommendDish();
      final state = c.read(decideControllerProvider);
      expect(state.recommendation, isNull);
      expect(state.recommendationError, contains('did not fit'));
    });

    test('comparing needs two photos', () async {
      final c = open(Rig(), FakeComparison());
      final controller = c.read(decideControllerProvider.notifier);
      await controller.pickPhoto(0, PhotoSource.gallery);
      expect(c.read(decideControllerProvider).canComparePhotos, isFalse);
      await controller.pickPhoto(1, PhotoSource.camera);
      expect(c.read(decideControllerProvider).canComparePhotos, isTrue);
    });

    test('a typed budget is validated before anything is uploaded', () async {
      final rig = Rig();
      final c = open(rig, FakeComparison());
      await twoPhotos(c);
      final controller = c.read(decideControllerProvider.notifier)
        ..toggleBudgetMode()
        ..setBudgetText('9999');
      await controller.comparePhotos();
      expect(c.read(decideControllerProvider).error, budgetMessage);
      expect(rig.media.uploads, isEmpty);
    });

    test('a result is shown with its budget and cleared by changes', () async {
      final comparison = FakeComparison()
        ..ranked = [rank('0', 1), rank('1', 2)];
      final c = open(Rig(), comparison);
      await twoPhotos(c);
      final controller = c.read(decideControllerProvider.notifier)
        ..toggleBudgetMode()
        ..setBudgetText('600');
      await controller.comparePhotos();
      var state = c.read(decideControllerProvider);
      expect(state.result!.meals, hasLength(2));
      expect(state.resultBudget, 600);
      controller.setBudgetText('700');
      expect(c.read(decideControllerProvider).result, isNull);
    });

    test('replacing and removing photos delete the old uploads', () async {
      final rig = Rig();
      final comparison = FakeComparison()
        ..ranked = [rank('0', 1), rank('1', 2)];
      final c = open(rig, comparison);
      await twoPhotos(c);
      final controller = c.read(decideControllerProvider.notifier);
      await controller.comparePhotos();
      await controller.pickPhoto(0, PhotoSource.camera);
      expect(rig.media.discarded, ['u/photo.jpg']);
      controller.removePhoto(1);
      await Future<void>.delayed(Duration.zero);
      expect(rig.media.discarded, hasLength(2));
      expect(c.read(decideControllerProvider).photos[1], isNull);
    });

    test('a third option can be added and removed', () {
      final c = open(Rig(), FakeComparison());
      final controller = c.read(decideControllerProvider.notifier)..addOption();
      expect(c.read(decideControllerProvider).photos, hasLength(3));
      expect(c.read(decideControllerProvider).canAddOption, isFalse);
      controller.removePhoto(2);
      expect(c.read(decideControllerProvider).photos, hasLength(2));
    });

    test('choosing a meal keeps the photos until it is logged', () async {
      final rig = Rig();
      final comparison = FakeComparison()
        ..ranked = [rank('0', 1), rank('1', 2)];
      final c = open(rig, comparison);
      await twoPhotos(c);
      final controller = c.read(decideControllerProvider.notifier);
      await controller.comparePhotos();
      final args = controller.reviewFor(
        c.read(decideControllerProvider).result!.meals.first,
      );
      expect(args.discardOnLeave, isFalse);
      expect(args.photo, isNotNull);
      expect(args.draft.source, MealSource.comparison);
      expect(rig.media.discarded, isEmpty);
      controller.finishChoice();
      await Future<void>.delayed(Duration.zero);
      expect(rig.media.discarded, hasLength(2));
      expect(c.read(decideControllerProvider).photos.nonNulls, isEmpty);
    });

    test('leaving the screen deletes uploaded photos', () async {
      final rig = Rig();
      final comparison = FakeComparison()
        ..ranked = [rank('0', 1), rank('1', 2)];
      final c = ProviderContainer(
        overrides: [
          ...rig.overrides,
          comparisonRepositoryProvider.overrideWithValue(comparison),
        ],
      );
      final subscription = c.listen(decideControllerProvider, (_, _) {});
      await twoPhotos(c);
      await c.read(decideControllerProvider.notifier).comparePhotos();
      subscription.close();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(rig.media.discarded, hasLength(2));
      c.dispose();
    });

    test('menu preparation: sample, typed and scanned', () async {
      final rig = Rig(demo: true);
      final comparison = FakeComparison();
      final c = open(rig, comparison);
      final controller = c.read(decideControllerProvider.notifier);
      final typed = await controller.prepareMenu();
      expect(typed!.options, hasLength(2));
      final sample = await controller.prepareMenu(sample: true);
      expect(sample!.options, isEmpty);
      final scanned = await controller.prepareMenu(scan: PhotoSource.gallery);
      expect(scanned!.options.single.name, 'Dal');
      expect(scanned.photo, isNotNull);
      expect(rig.media.discarded, ['u/photo.jpg']);
      rig.picker.error = const Failure('No camera.');
      expect(await controller.prepareMenu(scan: PhotoSource.camera), isNull);
      expect(c.read(decideControllerProvider).error, 'No camera.');
    });
  });

  group('decide screen planned-dish flow', () {
    testWidgets('shows a budgeted recommendation without a logging action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rig = Rig(
        overview: Overview(
          profile: const Profile(height: 170, weight: 70, target: 2000),
          targets: const [TargetSnapshot('2026-01-01', 2000)],
          localDay: DateTime.utc(2026, 6, 1),
        ),
      );
      final comparison = FakeComparison();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            overviewProvider.overrideWith((ref) async => rig.overviews.value),
            comparisonRepositoryProvider.overrideWithValue(comparison),
          ],
          child: MaterialApp(
            theme: plateTheme(),
            home: const Scaffold(body: DecideScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Dish you plan to cook'),
        'Vegetable curry',
      );
      await tester.tap(find.text('Suggest a portion'));
      await tester.pumpAndSettle();
      expect(find.text('One small bowl'), findsOneWidget);
      expect(find.textContaining('300–450 kcal estimated'), findsOneWidget);
      expect(find.text('Possible recipe adjustments'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.textContaining('Use less oil'), findsOneWidget);
      expect(
        find.textContaining('This plan has not been logged'),
        findsOneWidget,
      );
      expect(find.text('Confirm and log meal'), findsNothing);
      expect(rig.meals.saved, isEmpty);
    });
  });

  group('menu review screen', () {
    Future<Rig> show(
      WidgetTester tester,
      FakeComparison comparison,
      MenuReviewArgs args,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rig = Rig();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => MenuReviewScreen(args)),
          GoRoute(
            path: Routes.review,
            builder: (_, state) =>
                Text('review ${(state.extra! as ReviewArgs).draft.id}'),
          ),
          GoRoute(path: Routes.today, builder: (_, _) => const Text('today')),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rig.overrides,
            comparisonRepositoryProvider.overrideWithValue(comparison),
          ],
          child: MaterialApp.router(theme: plateTheme(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return rig;
    }

    testWidgets('compares the selected dishes and opens the chosen one', (
      tester,
    ) async {
      final comparison = FakeComparison()
        ..ranked = [rank('0', 1), rank('1', 2)];
      await show(
        tester,
        comparison,
        const MenuReviewArgs([
          MenuOption('Dal'),
          MenuOption('Rice'),
          MenuOption('Egg'),
        ], 500),
      );
      expect(find.text('Check menu options'), findsOneWidget);
      await tester.tap(find.text('Compare selected dishes'));
      await tester.pumpAndSettle();
      expect(comparison.compared.single.map((o) => o.key), ['0', '1', '2']);
      expect(find.text('Comparison results'), findsOneWidget);
      expect(find.text('500 kcal meal budget'), findsOneWidget);
      await tester.tap(find.text('Choose this meal').first);
      await tester.pumpAndSettle();
      expect(find.text('review r1'), findsOneWidget);
    });

    testWidgets('needs two named dishes selected', (tester) async {
      final comparison = FakeComparison();
      await show(
        tester,
        comparison,
        const MenuReviewArgs([MenuOption(''), MenuOption('')], null),
      );
      await tester.tap(find.text('Compare selected dishes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter names and select two or three dishes to compare.'),
        findsOneWidget,
      );
      expect(comparison.compared, isEmpty);
    });

    testWidgets('a dish can be corrected and a fourth cannot be selected', (
      tester,
    ) async {
      final comparison = FakeComparison();
      await show(
        tester,
        comparison,
        const MenuReviewArgs([
          MenuOption('A'),
          MenuOption('B'),
          MenuOption('C'),
          MenuOption('D'),
        ], null),
      );
      final boxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((c) => c.value);
      expect(boxes, [true, true, true, false]);
      await tester.tap(find.byTooltip('Edit dish 1'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dish name'),
        'Daal',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Daal'), findsOneWidget);
    });
  });
}

/// Media storage whose uploads fail when [fail] returns true.
class _FlakyMedia extends FakeMedia {
  _FlakyMedia(this.fail);
  final bool Function() fail;
  @override
  Future<String?> upload(Uint8List bytes) async {
    if (fail()) throw const Failure('Upload failed.');
    return super.upload(bytes);
  }
}
