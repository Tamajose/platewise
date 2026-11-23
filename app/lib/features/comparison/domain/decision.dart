import 'dart:math' as math;

import '../../../core/domain/domain.dart';

/// Orders two meals for a budget: fit first, then overage, then confidence,
/// then relative range width. Negative means [a] ranks ahead of [b].
int compareFit(
  CalorieRange a,
  Confidence ac,
  CalorieRange b,
  Confidence bc,
  int? budget,
) {
  List<int> score(CalorieRange range, Confidence confidence) => [
    budgetFit(range, budget).index,
    budget == null ? 0 : math.max(0, range.low - budget),
    Confidence.high.index - confidence.index,
    (1000 * (range.high - range.low) / math.max(1, range.low + range.high))
        .round(),
  ];
  final x = score(a, ac);
  final y = score(b, bc);
  for (var i = 0; i < x.length; i++) {
    final order = x[i].compareTo(y[i]);
    if (order != 0) return order;
  }
  return 0;
}

String fitReason(BudgetFit fit) => switch (fit) {
  BudgetFit.fits =>
    'The full estimated range fits this budget at the stated portion.',
  BudgetFit.overlaps =>
    'The range crosses your budget. The actual portion can change the fit.',
  BudgetFit.above =>
    'The lower end of the range exceeds this budget at the stated portion.',
  BudgetFit.noBudget => 'Set a meal budget to check fit.',
};

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
