import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/domain.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/presentation/session_state.dart';
import '../data/meal_log_providers.dart';
import '../domain/food_entry.dart';

class ReviewState {
  const ReviewState({
    required this.draft,
    this.busy = false,
    this.saved = false,
    this.error,
  });

  final MealDraft draft;
  final bool busy, saved;
  final String? error;

  bool get canSave => canLogMeal(draft);
  bool get tooLarge => draft.range.high > maxMealCalories;
  bool get canAddFood => draft.items.length < maxFoodsPerMeal;

  ReviewState copyWith({
    MealDraft? draft,
    bool? busy,
    bool? saved,
    String? error,
    bool clearError = false,
  }) => ReviewState(
    draft: draft ?? this.draft,
    busy: busy ?? this.busy,
    saved: saved ?? this.saved,
    error: clearError ? null : error ?? this.error,
  );
}

/// State of the review screen: the draft being edited and the save request.
class ReviewController extends Notifier<ReviewState> {
  ReviewController(this.args);

  final ReviewArgs args;

  @override
  ReviewState build() => ReviewState(draft: args.draft);

  /// Adds [food], or replaces the food at [index].
  void putFood(int? index, FoodItem food) {
    final items = [...state.draft.items];
    if (index == null) {
      items.add(food);
    } else {
      items[index] = food;
    }
    state = state.copyWith(draft: state.draft.revise(items), clearError: true);
  }

  void removeFood(int index) {
    final items = [...state.draft.items]..removeAt(index);
    state = state.copyWith(draft: state.draft.revise(items));
  }

  /// Saves the draft to the log. Returns whether it was saved; on failure
  /// [ReviewState.error] says why.
  Future<bool> save() async {
    final current = state;
    if (current.busy || !current.canSave) return false;
    state = current.copyWith(busy: true, clearError: true);
    try {
      await ref.read(mealLogRepositoryProvider).save(current.draft);
      if (!ref.mounted) return true;
      state = state.copyWith(busy: false, saved: true);
      ref.invalidate(overviewProvider);
      return true;
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
      return false;
    }
  }

  /// Deletes the draft's uploaded photo when the person leaves without saving.
  Future<void> discardIfAbandoned() async {
    final current = state;
    if (!args.discardOnLeave ||
        current.saved ||
        current.draft.isSaved ||
        current.draft.imagePath == null) {
      return;
    }
    try {
      await ref.read(mediaStorageProvider).discard(current.draft.imagePath);
    } on Object {
      /* Periodic cleanup handles abandoned uploads. */
    }
  }
}

final reviewControllerProvider = NotifierProvider.autoDispose
    .family<ReviewController, ReviewState, ReviewArgs>(ReviewController.new);

/// A temporary link to the photo of a saved meal.
final mealImageProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, mealId) => ref.watch(mealLogRepositoryProvider).imageUrl(mealId),
);
