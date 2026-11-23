import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/domain.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/presentation/session_state.dart';
import '../data/comparison_providers.dart';
import '../domain/compare_photos.dart';
import '../domain/decision.dart';
import 'menu_review_args.dart';

class DecideState {
  const DecideState({
    this.photos = const [null, null],
    this.useRemaining = true,
    this.budgetText = '',
    this.result,
    this.resultBudget,
    this.busy = false,
    this.error,
  });

  /// One entry per option slot, null while the slot is empty.
  final List<Uint8List?> photos;

  /// Whether the budget is what is left of today's, not a typed amount.
  final bool useRemaining;
  final String budgetText;
  final DecisionResult? result;
  final int? resultBudget;
  final bool busy;
  final String? error;

  int get photoCount => photos.nonNulls.length;
  bool get canComparePhotos => photoCount >= minComparedPhotos;
  bool get canAddOption => photos.length < maxComparedPhotos;

  DecideState copyWith({
    List<Uint8List?>? photos,
    bool? useRemaining,
    String? budgetText,
    DecisionResult? result,
    int? resultBudget,
    bool? busy,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) => DecideState(
    photos: photos ?? this.photos,
    useRemaining: useRemaining ?? this.useRemaining,
    budgetText: budgetText ?? this.budgetText,
    result: clearResult ? null : result ?? this.result,
    resultBudget: clearResult ? null : resultBudget ?? this.resultBudget,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
  );
}

/// State of the Decide screen: the budget, the photos being compared and the
/// ranked result. Photos uploaded for a comparison are deleted when the
/// screen closes.
class DecideController extends Notifier<DecideState> {
  /// Where each photo was uploaded. Kept outside the state because the screen
  /// never shows it, but cleanup needs it even after the screen closes.
  final _paths = <String?>[null, null];

  @override
  DecideState build() {
    final media = ref.read(mediaStorageProvider);
    ref.onDispose(() => unawaited(_discardAll(media, [..._paths])));
    return const DecideState();
  }

  void setBudgetText(String text) =>
      state = state.copyWith(budgetText: text, clearResult: true);

  void toggleBudgetMode() => state = state.copyWith(
    useRemaining: !state.useRemaining,
    clearResult: true,
  );

  void addOption() {
    if (!state.canAddOption) return;
    _paths.add(null);
    state = state.copyWith(photos: [...state.photos, null]);
  }

  Future<void> pickPhoto(int index, PhotoSource source) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final photo = await ref.read(photoPickerProvider).pick(source);
      if (!ref.mounted) return;
      if (photo == null) {
        state = state.copyWith(busy: false);
        return;
      }
      final previous = _paths[index];
      _paths[index] = null;
      final photos = [...state.photos]..[index] = photo;
      state = state.copyWith(busy: false, photos: photos, clearResult: true);
      await _discard(ref.read(mediaStorageProvider), previous);
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
    }
  }

  /// Empties a slot. The third slot disappears.
  void removePhoto(int index) {
    final previous = _paths[index];
    final photos = [...state.photos];
    if (index == 2) {
      _paths.removeAt(index);
      photos.removeAt(index);
    } else {
      _paths[index] = null;
      photos[index] = null;
    }
    state = state.copyWith(photos: photos, clearResult: true);
    unawaited(_discard(ref.read(mediaStorageProvider), previous));
  }

  Future<void> comparePhotos() async {
    if (state.busy || !state.canComparePhotos) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final budget = _readBudget();
      final result =
          await ComparePhotos(
            ref.read(comparisonRepositoryProvider),
            ref.read(mediaStorageProvider),
          )(
            photos: state.photos,
            paths: _paths,
            budget: budget,
            isOpen: () => ref.mounted,
          );
      if (ref.mounted) {
        state = state.copyWith(
          busy: false,
          result: result,
          resultBudget: budget,
        );
      }
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
    }
  }

  /// Gets the dishes for the menu review screen: from a photographed menu
  /// ([scan] with a [source]), the built-in sample, or two blank rows. Returns
  /// null when it failed or the person cancelled; [DecideState.error] says why.
  Future<MenuReviewArgs?> prepareMenu({
    PhotoSource? scan,
    bool sample = false,
  }) async {
    final media = ref.read(mediaStorageProvider);
    String? uploaded;
    state = state.copyWith(busy: scan != null, clearError: true);
    try {
      final overview = ref.read(overviewProvider).value;
      final budget = _readBudget();
      final language = overview?.profile?.language ?? 'en';
      final repository = ref.read(comparisonRepositoryProvider);
      if (scan != null) {
        final photo = await ref.read(photoPickerProvider).pick(scan);
        if (photo == null || !ref.mounted) return null;
        uploaded = await media.upload(photo);
        final options = await repository.extractMenu(uploaded);
        return MenuReviewArgs(
          options,
          budget,
          photo: photo,
          language: language,
        );
      }
      return MenuReviewArgs(
        sample
            ? repository.sampleMenu() ?? const []
            : const [MenuOption(''), MenuOption('')],
        budget,
        sample: sample,
        language: language,
      );
    } on Object catch (e) {
      if (ref.mounted) state = state.copyWith(error: failureMessage(e));
      return null;
    } finally {
      await _discard(media, uploaded);
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// The review screen arguments for logging [meal], with the photo it was
  /// estimated from. The photos stay uploaded until [finishChoice].
  ReviewArgs reviewFor(RankedMeal meal) {
    final index = int.tryParse(meal.key);
    return ReviewArgs(
      meal.draft.choose(MealSource.comparison),
      photo: index == null ? null : state.photos[index],
      discardOnLeave: false,
    );
  }

  /// Clears the comparison after the chosen meal was logged and deletes the
  /// uploaded photos.
  void finishChoice() {
    final cleanup = [..._paths];
    for (var i = 0; i < _paths.length; i++) {
      _paths[i] = null;
    }
    state = state.copyWith(
      photos: List.filled(state.photos.length, null),
      clearResult: true,
    );
    unawaited(_discardAll(ref.read(mediaStorageProvider), cleanup));
  }

  int? _readBudget() => state.useRemaining
      ? suggestedBudget(ref.read(overviewProvider).value)
      : parseMealBudget(state.budgetText);

  Future<void> _discardAll(MediaStorage media, List<String?> paths) =>
      Future.wait(paths.map((p) => _discard(media, p)));

  Future<void> _discard(MediaStorage media, String? path) async {
    if (path == null) return;
    try {
      await media.discard(path);
    } on Object {
      /* The retention sweep can retry. */
    }
  }
}

final decideControllerProvider =
    NotifierProvider.autoDispose<DecideController, DecideState>(
      DecideController.new,
    );
