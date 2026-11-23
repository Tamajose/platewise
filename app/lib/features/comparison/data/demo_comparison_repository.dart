import '../../../core/data/demo/demo_analysis.dart';
import '../../../core/data/ids.dart';
import '../../../core/domain/domain.dart';
import '../domain/comparison_repository.dart';
import '../domain/decision.dart';

/// Demo mode: menu dishes are estimated from the local catalog, and photos
/// cannot be analysed.
class DemoComparisonRepository implements ComparisonRepository {
  DemoComparisonRepository({this._generateId = newId});

  final IdGenerator _generateId;

  @override
  Future<List<MenuOption>> extractMenu(String? imagePath) async {
    throw const Failure(
      'Scanning your own menu needs a configured backend. Try the labeled sample or type dishes.',
      code: 'DEMO_ONLY',
    );
  }

  @override
  Future<MealDraft> estimatePhoto(String? imagePath) async {
    throw const Failure(
      'Live photo analysis needs a configured backend. Try a labeled sample or enter the photo’s foods manually.',
      code: 'DEMO_ONLY',
    );
  }

  @override
  List<MenuOption>? sampleMenu() => const [
    MenuOption('Chicken tikka rice bowl', portion: 'One bowl with rice'),
    MenuOption('Vegetable khichuri', portion: 'One bowl'),
    MenuOption('Chicken biryani', portion: 'One medium portion'),
  ];

  @override
  Future<DecisionResult> compare(
    List<DecisionOption> options,
    int? budget,
  ) async {
    final successes = <({String key, MealDraft draft, int index})>[];
    final failures = <DecisionFailure>[];
    for (var index = 0; index < options.length; index++) {
      final option = options[index];
      try {
        final dish = option.menu;
        if (dish == null) {
          throw const Failure(
            'Live photo estimation is unavailable in demo mode.',
          );
        }
        successes.add((
          key: option.key,
          draft: _estimate(dish, option.language),
          index: index,
        ));
      } on Object catch (error) {
        failures.add((
          key: option.key,
          message: messageFor(error),
          retryable: false,
        ));
      }
    }
    successes.sort((a, b) {
      final order = compareFit(
        a.draft.range,
        a.draft.confidence,
        b.draft.range,
        b.draft.confidence,
        budget,
      );
      return order != 0 ? order : a.index.compareTo(b.index);
    });
    return DecisionResult([
      for (var i = 0; i < successes.length; i++)
        RankedMeal(
          successes[i].key,
          successes[i].draft,
          i + 1,
          budgetFit(successes[i].draft.range, budget),
          fitReason(budgetFit(successes[i].draft.range, budget)),
        ),
    ], failures);
  }

  MealDraft _estimate(MenuOption dish, String language) {
    if (dish.kcal case final int kcal) {
      return MealDraft(
        id: _generateId(),
        source: MealSource.menu,
        items: [
          FoodItem(
            name: dish.name,
            quantity: 1,
            unit: 'serving',
            range: CalorieRange(kcal, kcal),
            provenance: 'menu_text',
          ),
        ],
        assumptions: [
          dish.portion ?? 'One menu serving',
          'Calories supplied during menu review.',
        ],
        confidence: Confidence.medium,
        model: 'demo-fixtures',
      );
    }
    final result = analyzeDemoText(
      dish.name,
      language,
      id: _generateId(),
      source: MealSource.menu,
    );
    return MealDraft(
      id: result.id,
      source: result.source,
      items: result.items,
      model: result.model,
      assumptions: [
        dish.portion ?? 'One typical serving',
        'Illustrative nutrition inferred from the name.',
      ],
    );
  }
}
