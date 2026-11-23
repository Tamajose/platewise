import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/settings/domain/energy.dart';

void main() {
  test('Mifflin–St Jeor resting energy and a separate activity factor', () {
    const profile = Profile(height: 168, weight: 70, target: null);
    final male = calculateEnergy(profile, 30, 'plus_5', 'low');
    expect(male.resting, 1605);
    expect(male.multiplier, 1.2);
    expect(male.total, 1926);
    expect(male.canApply, isTrue);

    final female = calculateEnergy(profile, 30, 'minus_161', 'some');
    expect(female.resting, 1439);
    expect(female.total, 2015);
  });

  test('every activity level has a displayed multiplier', () {
    expect(energyMultipliers, {'low': 1.2, 'some': 1.4, 'regular': 1.6});
  });

  test('a total below the accepted range cannot be applied', () {
    const small = Profile(height: 150, weight: 40, target: null);
    final estimate = calculateEnergy(small, 60, 'minus_161', 'low');
    expect(estimate.total, lessThan(targetMinimum));
    expect(estimate.canApply, isFalse);
  });
}
