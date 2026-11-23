import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/meal_log_repository.dart';
import '../domain/voice.dart';

/// Overridden by the composition root with the demo or live implementation.
final mealLogRepositoryProvider = Provider<MealLogRepository>(
  (ref) => throw StateError('Meal log repository initialization required'),
);

/// Overridden by the composition root with the demo or live implementation.
final speechTranscriberProvider = Provider<SpeechTranscriber>(
  (ref) => throw StateError('Speech transcriber initialization required'),
);

/// Overridden by the composition root. The recorder is created when voice
/// entry opens and released when it closes, so overrides call `ref.onDispose`.
final voiceRecorderProvider = Provider.autoDispose<VoiceRecorder>(
  (ref) => throw StateError('Voice recorder initialization required'),
);
