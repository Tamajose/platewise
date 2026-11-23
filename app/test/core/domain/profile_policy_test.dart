import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/presentation/failure_message.dart';

void main() {
  test('BMI and unit conversion', () {
    const p = Profile(height: 170, weight: 70, target: 1200, units: 'us');
    expect(p.bmi, closeTo(24.221, .001));
    expect(p.displayWeight, closeTo(154.324, .001));
    expect(p.displayHeight, closeTo(66.929, .001));
    const metric = Profile(height: 170, weight: 70, target: null);
    expect(metric.displayWeight, 70);
    expect(metric.displayHeight, 170);
  });

  test('target policy accepts the pilot range and an absent target', () {
    for (final target in [null, 1200, 1201, 4999, 5000]) {
      expect(targetError(target), isNull);
    }
    for (final target in [1199, 5001]) {
      expect(targetError(target), targetGuidance);
    }
  });

  test('a failure keeps its detail and its own message is shown', () {
    const failure = Failure(
      'Model unavailable',
      code: 'PROVIDER',
      retryable: true,
      requestId: 'r1',
    );
    expect(failure.toString(), 'Model unavailable');
    expect(failure.retryable, isTrue);
    expect(failureMessage(failure), 'Model unavailable');
    expect(const Failure('x').code, 'UNAVAILABLE');
  });

  test('other errors get a generic safe message', () {
    final message = failureMessage(StateError('secret internal detail'));
    expect(message, contains('could not finish that request'));
    expect(message, isNot(contains('secret')));
  });
}
