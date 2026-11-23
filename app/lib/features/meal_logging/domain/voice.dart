import 'dart:typed_data';

/// How long a voice note may run before recording stops by itself.
const maxVoiceSeconds = 40;

/// The largest voice note the service accepts.
const maxVoiceBytes = 2 * 1024 * 1024;

class VoiceRecording {
  const VoiceRecording({
    required this.bytes,
    required this.filename,
    required this.mime,
  });
  final Uint8List bytes;
  final String filename, mime;
}

/// Records a short voice note on this device.
abstract interface class VoiceRecorder {
  /// Starts recording. Throws a `Failure` when the microphone is not allowed.
  Future<void> start();

  /// Stops recording and returns what was captured. Throws a `Failure` when
  /// nothing was captured.
  Future<VoiceRecording> stop();

  /// Stops recording and throws the audio away.
  Future<void> cancel();

  /// Releases the microphone.
  Future<void> dispose();
}

/// Turns a voice note into text.
abstract interface class SpeechTranscriber {
  Future<String> transcribe(VoiceRecording recording, String language);
}
