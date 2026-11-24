/// Pilot policy for very small meal budgets. Like the daily target range, the
/// number is a product safeguard that needs clinical and product review before
/// a public release. The backend uses the same value.
///
/// Below this many kcal the app does not size a portion of a cooked dish,
/// because any portion it suggested would be a spoonful, not a meal. Comparing
/// and logging stay available, since they only describe food.
const minPlannableBudget = 150;

/// Shown when a planned dish cannot be sized for the budget. It says what is
/// still possible and never tells anyone to eat less or skip a meal.
const planBudgetTooSmallMessage =
    'A budget under $minPlannableBudget kcal is too small to size a portion of a cooked dish. You can still compare options or log what you eat. If you are unsure how much to eat, a qualified healthcare professional or dietitian can help.';

/// Shown beside a small budget in Decide.
const smallBudgetNote =
    'Only a small amount is left for this meal, so most options will be above it. You can still compare, view and log any dish.';

/// Whether [budget] is too small to size a portion for. No budget is not small.
bool isSmallBudget(int? budget) =>
    budget != null && budget < minPlannableBudget;
