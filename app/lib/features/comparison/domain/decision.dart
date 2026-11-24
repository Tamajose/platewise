import '../../../core/domain/domain.dart';

class MenuOption {
  const MenuOption(this.name, {this.portion, this.kcal});
  final String name;
  final String? portion;
  final int? kcal;
}

class DecisionOption {
  const DecisionOption.photo(this.key, this.path)
    : menu = null,
      language = 'en';
  const DecisionOption.menu(this.key, this.menu, {this.language = 'en'})
    : path = null;
  final String key, language;
  final String? path;
  final MenuOption? menu;
}

class RankedMeal {
  const RankedMeal(this.key, this.draft, this.rank, this.fit, this.reason);
  final String key, reason;
  final MealDraft draft;
  final BudgetFit fit;
  final int rank;
}

typedef DecisionFailure = ({String key, String message, bool retryable});

class DecisionResult {
  const DecisionResult(this.meals, this.failures);
  final List<RankedMeal> meals;
  final List<DecisionFailure> failures;
}

class DishRecommendation {
  const DishRecommendation({
    required this.portion,
    required this.adjustments,
    required this.range,
    required this.confidence,
    required this.assumptions,
  });
  final String portion;
  final List<String> adjustments;
  final CalorieRange range;
  final Confidence confidence;
  final List<String> assumptions;
}
