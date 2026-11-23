import 'calorie_range.dart';

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
