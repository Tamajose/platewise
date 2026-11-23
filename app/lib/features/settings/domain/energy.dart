import '../../../core/domain/domain.dart';

typedef EnergyEstimate = ({
  int resting,
  int total,
  double multiplier,
  bool canApply,
});

/// Activity heuristics shown to the person. They are not coefficients from the
/// Mifflin–St Jeor study.
const energyMultipliers = {'low': 1.2, 'some': 1.4, 'regular': 1.6};

/// Mifflin–St Jeor resting energy times an activity multiplier. [coefficient]
/// is `plus_5` or `minus_161`. [canApply] says whether the total is inside the
/// accepted target range.
EnergyEstimate calculateEnergy(
  Profile profile,
  int age,
  String coefficient,
  String activity,
) {
  final rest =
      10 * profile.weight +
      6.25 * profile.height -
      5 * age +
      (coefficient == 'plus_5' ? 5 : -161);
  final multiplier = energyMultipliers[activity]!;
  final total = (rest * multiplier).round();
  return (
    resting: rest.round(),
    total: total,
    multiplier: multiplier,
    canApply: targetError(total) == null,
  );
}

typedef Correction = ({String food, int grams, CalorieRange range});
