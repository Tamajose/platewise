/// Pilot policy for the daily calorie target. The bounds are product
/// safeguards that need clinical and product review before a public release.
const targetMinimum = 1200, targetMaximum = 5000;
const targetGuidance =
    'This pilot accepts 1,200–5,000 kcal. You can keep logging without a target. Please speak with a qualified healthcare professional about your individual calorie needs, especially if a target below 1,200 kcal seems necessary.';

/// Returns guidance text when [target] is outside the accepted range, or null
/// when it is acceptable or absent.
String? targetError(int? target) =>
    target != null && (target < targetMinimum || target > targetMaximum)
    ? targetGuidance
    : null;
