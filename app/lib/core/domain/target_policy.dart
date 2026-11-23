/// Pilot policy for the daily calorie target. The bounds are product
/// safeguards that need clinical and product review before a public release.
const targetMinimum = 1200, targetMaximum = 5000;
const targetGuidance =
    'This pilot accepts 1,200–5,000 kcal. If your needs fall outside that range, you can keep logging without a target and speak with a qualified professional.';

/// Returns guidance text when [target] is outside the accepted range, or null
/// when it is acceptable or absent.
String? targetError(int? target) =>
    target != null && (target < targetMinimum || target > targetMaximum)
    ? targetGuidance
    : null;
