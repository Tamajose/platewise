import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/comparison/domain/decision.dart';

void main() {
  test('edge boundaries and tie handling agree with server vectors', () {
    const meal = CalorieRange(400, 600);
    expect(budgetFit(meal, 600), BudgetFit.fits);
    expect(budgetFit(meal, 400), BudgetFit.overlaps);
    expect(budgetFit(meal, 399), BudgetFit.above);
    expect(budgetFit(meal, null), BudgetFit.noBudget);
    expect(
      compareFit(
        const CalorieRange(460, 500),
        Confidence.low,
        const CalorieRange(400, 460),
        Confidence.low,
        600,
      ),
      lessThan(0),
    );
    expect(compareFit(meal, Confidence.low, meal, Confidence.low, 600), 0);
  });

  test('fit decides first, then overage, then confidence, then width', () {
    const fits = CalorieRange(300, 500);
    const over = CalorieRange(650, 700);
    expect(
      compareFit(fits, Confidence.low, over, Confidence.high, 600),
      lessThan(0),
    );
    expect(
      compareFit(
        over,
        Confidence.low,
        const CalorieRange(900, 950),
        Confidence.low,
        600,
      ),
      lessThan(0),
    );
    expect(
      compareFit(fits, Confidence.high, fits, Confidence.low, 600),
      lessThan(0),
    );
    expect(
      compareFit(
        const CalorieRange(400, 410),
        Confidence.low,
        const CalorieRange(300, 500),
        Confidence.low,
        600,
      ),
      lessThan(0),
    );
  });

  test('lower calories alone never win', () {
    expect(
      compareFit(
        const CalorieRange(100, 500),
        Confidence.low,
        const CalorieRange(450, 500),
        Confidence.low,
        600,
      ),
      greaterThan(0),
    );
  });

  test('every fit has an explanation', () {
    for (final fit in BudgetFit.values) {
      expect(fitReason(fit), isNotEmpty);
    }
  });

  test('demo location distance matches server distance in km', () {
    expect(distanceKm(0, 0, 0, 1), closeTo(111.195, .01));
    expect(distanceKm(23.4607, 91.1809, 23.4607, 91.1809), 0);
  });
}
