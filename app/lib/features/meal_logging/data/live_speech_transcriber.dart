import '../../../core/data/api/api_client.dart';
import '../../../core/domain/failure.dart';
import '../domain/voice.dart';

class LiveSpeechTranscriber implements SpeechTranscriber {
  LiveSpeechTranscriber(this._api);

  final ApiClient _api;

  @override
  Future<String> transcribe(VoiceRecording recording, String language) async {
    final data = await _api.callWithFile(
      'transcribe_voice',
      fields: {'language': language},
      fileField: 'audio',
      bytes: recording.bytes,
      filename: recording.filename,
      contentType: recording.mime,
      timedOut: const Failure(
        'Transcription took too long. Try again or type the meal.',
      ),
      offline: const Failure(
        'Speech service is offline. Type the meal to continue.',
      ),
    );
    return data['transcript'] as String;
  }
}
