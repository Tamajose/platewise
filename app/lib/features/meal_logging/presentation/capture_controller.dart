import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/domain.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/presentation/ai_language.dart';
import '../data/meal_log_providers.dart';

enum CaptureMethod { photo, text, voice }

const minDescriptionLength = 2;
const maxDescriptionLength = 600;

class CaptureState {
  const CaptureState({
    this.method = CaptureMethod.photo,
    this.photo,
    this.description = '',
    this.language = 'en',
    this.busy = false,
    this.error,
  });

  final CaptureMethod method;
  final Uint8List? photo;
  final String description, language;
  final bool busy;
  final String? error;

  bool get isPhoto => method == CaptureMethod.photo;

  /// Whether there is enough to estimate from.
  bool get canEstimate => isPhoto
      ? photo != null
      : description.trim().length >= minDescriptionLength;

  CaptureState copyWith({
    CaptureMethod? method,
    Uint8List? photo,
    String? description,
    String? language,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => CaptureState(
    method: method ?? this.method,
    photo: photo ?? this.photo,
    description: description ?? this.description,
    language: language ?? this.language,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
  );
}

/// State of the "what did you eat" screen: the chosen input, the photo or
/// text, and the estimate request.
class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => CaptureState(language: ref.read(aiLanguageProvider));

  void selectMethod(CaptureMethod method) {
    if (state.busy) return;
    state = state.copyWith(method: method, clearError: true);
  }

  void setDescription(String text) {
    if (text == state.description) return;
    state = state.copyWith(description: text);
  }

  void setLanguage(String language) =>
      state = state.copyWith(language: language);

  /// Fills the description from a voice transcript and switches to its
  /// language.
  void useTranscript(String text, String language) {
    state = state.copyWith(
      description: text.length > maxDescriptionLength
          ? text.substring(0, maxDescriptionLength)
          : text,
      language: language,
    );
  }

  Future<void> pickPhoto(PhotoSource source) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final bytes = await ref.read(photoPickerProvider).pick(source);
      if (!ref.mounted) return;
      state = bytes == null
          ? state.copyWith(busy: false)
          : state.copyWith(busy: false, photo: bytes);
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
    }
  }

  /// Estimates the meal. Returns the draft, or null when it failed, in which
  /// case [CaptureState.error] says why. A photo that was uploaded for a
  /// failed estimate is deleted.
  Future<MealDraft?> estimate() async {
    final snapshot = state;
    if (snapshot.busy || !snapshot.canEstimate) return null;
    final repository = ref.read(mealLogRepositoryProvider);
    final media = ref.read(mediaStorageProvider);
    state = snapshot.copyWith(busy: true, clearError: true);
    String? uploaded;
    try {
      final MealDraft draft;
      if (snapshot.isPhoto) {
        uploaded = await media.upload(snapshot.photo!);
        draft = await repository.analyzePhoto(uploaded);
      } else {
        draft = await repository.analyzeText(
          snapshot.description.trim(),
          snapshot.language,
          source: snapshot.method == CaptureMethod.voice
              ? MealSource.voice
              : MealSource.text,
        );
      }
      if (!ref.mounted) {
        await _discard(media, draft.imagePath);
        return null;
      }
      state = state.copyWith(busy: false);
      return draft;
    } on Object catch (e) {
      var message = failureMessage(e);
      if (uploaded != null && !await _discard(media, uploaded)) {
        message += ' Photo cleanup may still be pending.';
      }
      if (ref.mounted) state = state.copyWith(busy: false, error: message);
      return null;
    }
  }

  /// A blank draft for typing the foods in by hand.
  ReviewArgs manualReview() => ReviewArgs(
    MealDraft(
      id: ref.read(idGeneratorProvider)(),
      source: MealSource.manual,
      items: const [],
    ),
    photo: state.photo,
  );

  /// The built-in sample estimate, or null outside demo mode.
  ReviewArgs? sampleReview() {
    final draft = ref.read(mealLogRepositoryProvider).sampleDraft();
    return draft == null ? null : ReviewArgs(draft, editorial: true);
  }

  Future<bool> _discard(MediaStorage media, String? path) async {
    try {
      await media.discard(path);
      return true;
    } on Object {
      return false;
    }
  }
}

final captureControllerProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(
      CaptureController.new,
    );
