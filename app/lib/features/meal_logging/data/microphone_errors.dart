import '../../../core/domain/failure.dart';

/// Turns what the microphone plugin or the browser threw into a message that
/// tells the person what to do. Anything unrecognised gets the general
/// message, so no technical detail reaches the screen.
Failure microphoneFailure(Object error) {
  final text = error.toString().toLowerCase();
  bool mentions(List<String> words) => words.any(text.contains);

  if (mentions(['notallowederror', 'permission', 'denied'])) {
    return const Failure(
      'Microphone permission was denied. Allow the microphone for this site in your browser or device settings, then try again.',
    );
  }
  if (mentions(['notfounderror', 'devicesnotfound', 'no device'])) {
    return const Failure(
      'No microphone was found. Connect one, or type your meal.',
    );
  }
  if (mentions(['notreadableerror', 'trackstarterror', 'in use'])) {
    return const Failure(
      'The microphone is being used by another app. Close it and try again.',
    );
  }
  if (mentions(['securityerror', 'secure context'])) {
    return const Failure(
      'The browser blocks the microphone on this page. Open PlateWise over HTTPS or on localhost.',
    );
  }
  if (mentions(['missingplugin'])) {
    return const Failure(
      'The microphone is not ready yet. Reload the page and try again.',
    );
  }
  return const Failure(
    'Recording is unavailable here. Type your meal to continue.',
  );
}
