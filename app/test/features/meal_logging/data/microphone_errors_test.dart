import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/features/meal_logging/data/microphone_errors.dart';

void main() {
  String say(Object error) => microphoneFailure(error).message;

  test('a denied permission tells the person how to allow it', () {
    for (final error in [
      'NotAllowedError: Permission denied',
      Exception('Permission dismissed'),
    ]) {
      expect(say(error), contains('Allow the microphone'));
    }
  });

  test('a missing, busy or blocked microphone is named', () {
    expect(
      say('NotFoundError: Requested device not found'),
      contains('No microphone'),
    );
    expect(
      say('NotReadableError: Could not start audio source'),
      contains('another app'),
    );
    expect(
      say('SecurityError: only secure context'),
      contains('HTTPS or on localhost'),
    );
  });

  test('a plugin that is not ready after a hot restart asks for a reload', () {
    expect(
      say('MissingPluginException(No implementation found)'),
      contains('Reload the page'),
    );
  });

  test('anything else gets the general message with no detail', () {
    final message = say(StateError('internal state 0xDEADBEEF'));
    expect(
      message,
      'Recording is unavailable here. Type your meal to continue.',
    );
    expect(message, isNot(contains('DEADBEEF')));
  });
}
