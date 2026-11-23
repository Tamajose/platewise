import '../../domain/domain.dart';

/// The API names the no-budget case `no_budget`. The other names match.
BudgetFit budgetFitFromWire(String value) =>
    value == 'no_budget' ? BudgetFit.noBudget : BudgetFit.values.byName(value);
