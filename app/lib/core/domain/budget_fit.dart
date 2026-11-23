import 'dart:math' as math;

import 'calorie_range.dart';
import 'meal.dart';

enum BudgetFit {
  fits('Fits budget'),
  overlaps('Range overlaps budget'),
  above('Above budget'),
  noBudget('No budget set');

  const BudgetFit(this.label);
  final String label;
}

BudgetFit budgetFit(CalorieRange range, int? budget) {
  if (budget == null) return BudgetFit.noBudget;
  if (range.high <= budget) return BudgetFit.fits;
  if (range.low <= budget) return BudgetFit.overlaps;
  return BudgetFit.above;
}

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
