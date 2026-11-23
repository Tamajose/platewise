import '../../../core/domain/failure.dart';
import '../domain/voice.dart';

/// Demo mode has no speech service. The screen offers a sample transcript.
class DemoSpeechTranscriber implements SpeechTranscriber {
  const DemoSpeechTranscriber();

  @override
  Future<String> transcribe(VoiceRecording recording, String language) async {
    throw const Failure(
      'Live transcription is unavailable in demo mode. Type your meal or review the labeled sample transcript.',
    );
  }
}
