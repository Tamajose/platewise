import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/failure.dart';
import '../../../core/presentation/failure_message.dart';
import '../data/meal_log_providers.dart';
import '../domain/voice.dart';
import 'capture_controller.dart';

class VoiceState {
  const VoiceState({
    this.listening = false,
    this.busy = false,
    this.locale = 'en',
    this.error,
  });

  final bool listening, busy;
  final String locale;
  final String? error;

  VoiceState copyWith({
    bool? listening,
    bool? busy,
    String? locale,
    String? error,
    bool clearError = false,
  }) => VoiceState(
    listening: listening ?? this.listening,
    busy: busy ?? this.busy,
    locale: locale ?? this.locale,
    error: clearError ? null : error ?? this.error,
  );
}

/// Records a voice note, transcribes it, and puts the text into the capture
/// screen's description.
class VoiceController extends Notifier<VoiceState> {
  Timer? _timer;

  @override
  VoiceState build() {
    ref.onDispose(() => _timer?.cancel());
    return const VoiceState();
  }

  void setLocale(String locale) => state = state.copyWith(locale: locale);

  Future<void> start() async {
    if (state.busy || state.listening) return;
    state = state.copyWith(busy: true, clearError: true);
    final recorder = ref.read(voiceRecorderProvider);
    try {
      await recorder.start();
      if (!ref.mounted) {
        await recorder.cancel();
        return;
      }
      _timer = Timer(const Duration(seconds: maxVoiceSeconds), stop);
      state = state.copyWith(listening: true, busy: false);
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        busy: false,
        error: e is Failure
            ? e.message
            : 'Recording is unavailable here. Type your meal to continue.',
      );
    }
  }

  Future<void> stop() async {
    if (!state.listening || state.busy) return;
    _timer?.cancel();
    final locale = state.locale;
    state = state.copyWith(busy: true, listening: false, clearError: true);
    try {
      final recording = await ref.read(voiceRecorderProvider).stop();
      if (recording.bytes.length > maxVoiceBytes) {
        throw const Failure('Use a recording under 2 MB, or type your meal.');
      }
      final text = await ref
          .read(speechTranscriberProvider)
          .transcribe(recording, locale);
      if (!ref.mounted) return;
      ref.read(captureControllerProvider.notifier).useTranscript(text, locale);
      state = state.copyWith(busy: false);
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
    }
  }
}

final voiceControllerProvider =
    NotifierProvider.autoDispose<VoiceController, VoiceState>(
      VoiceController.new,
    );
