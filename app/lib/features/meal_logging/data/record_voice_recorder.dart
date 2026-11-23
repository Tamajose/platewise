import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

import '../../../core/data/ids.dart';
import '../../../core/domain/failure.dart';
import '../domain/voice.dart';
import 'audio_files.dart' if (dart.library.io) 'audio_files_native.dart';

/// Records with the `record` plugin: AAC on devices, Opus or WAV in browsers.
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _file;
  String _suffix = 'm4a';
  String _mime = 'audio/mp4';

  @override
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw const Failure(
        'Microphone permission was denied. Type your meal to continue.',
      );
    }
    var encoder = AudioEncoder.aacLc;
    if (kIsWeb) {
      final opus = await _recorder.isEncoderSupported(AudioEncoder.opus);
      _suffix = opus ? 'webm' : 'wav';
      _mime = opus ? 'audio/webm' : 'audio/wav';
      encoder = opus ? AudioEncoder.opus : AudioEncoder.wav;
    }
    final path = await audioPath('platewise-${newId()}.$_suffix');
    _file = path;
    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        sampleRate: 16000,
        bitRate: 64000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  @override
  Future<VoiceRecording> stop() async {
    try {
      final recorded = await _recorder.stop();
      if (recorded == null) {
        throw const Failure(
          'No recording was captured. Try again or type your meal.',
        );
      }
      return VoiceRecording(
        bytes: await XFile(recorded).readAsBytes(),
        filename: 'meal.$_suffix',
        mime: _mime,
      );
    } finally {
      await _forget();
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } finally {
      await _forget();
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } finally {
      await _forget();
    }
  }

  Future<void> _forget() async {
    final path = _file;
    _file = null;
    await forgetAudio(path);
  }
}
