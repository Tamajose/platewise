import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/review_args.dart';
import '../data/comparison_providers.dart';
import '../domain/compare_photos.dart';
import '../domain/decision.dart';
import 'menu_review_args.dart';

/// The most dishes that can be listed on the review screen.
const maxMenuDishes = 18;

class MenuReviewState {
  const MenuReviewState({
    required this.options,
    required this.selected,
    this.result,
    this.busy = false,
    this.error,
  });

  final List<MenuOption> options;
  final Set<int> selected;
  final DecisionResult? result;
  final bool busy;
  final String? error;

  bool get canAddDish => options.length < maxMenuDishes;

  MenuReviewState copyWith({
    List<MenuOption>? options,
    Set<int>? selected,
    DecisionResult? result,
    bool? busy,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) => MenuReviewState(
    options: options ?? this.options,
    selected: selected ?? this.selected,
    result: clearResult ? null : result ?? this.result,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
  );
}

/// State of the menu review screen: which dishes are listed and selected, and
/// the ranked comparison of the selection.
class MenuReviewController extends Notifier<MenuReviewState> {
  MenuReviewController(this.args);

  final MenuReviewArgs args;

  @override
  MenuReviewState build() => MenuReviewState(
    options: [...args.options],
    selected: {
      for (var i = 0; i < args.options.length && i < maxComparedPhotos; i++) i,
    },
  );

  void replaceDish(int index, MenuOption dish) {
    final options = [...state.options]..[index] = dish;
    state = state.copyWith(
      options: options,
      clearResult: true,
      clearError: true,
    );
  }

  /// Adds a dish, and selects it when fewer than three are selected.
  void addDish(MenuOption dish) {
    final selected = {...state.selected};
    if (selected.length < maxComparedPhotos) selected.add(state.options.length);
    state = state.copyWith(
      options: [...state.options, dish],
      selected: selected,
      clearResult: true,
    );
  }

  void select(int index, bool value) {
    final selected = {...state.selected};
    if (value && selected.length < maxComparedPhotos) selected.add(index);
    if (!value) selected.remove(index);
    state = state.copyWith(selected: selected, clearResult: true);
  }

  Future<void> compare() async {
    final chosen = state.selected.toList()..sort();
    if (chosen.length < minComparedPhotos ||
        chosen.any((i) => state.options[i].name.trim().isEmpty)) {
      state = state.copyWith(
        error: 'Enter names and select two or three dishes to compare.',
      );
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await ref.read(comparisonRepositoryProvider).compare([
        for (final i in chosen)
          DecisionOption.menu('$i', state.options[i], language: args.language),
      ], args.budget);
      if (ref.mounted) state = state.copyWith(busy: false, result: result);
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
    }
  }

  ReviewArgs reviewFor(RankedMeal meal) =>
      ReviewArgs(meal.draft.choose(MealSource.menu));
}

final menuReviewControllerProvider = NotifierProvider.autoDispose
    .family<MenuReviewController, MenuReviewState, MenuReviewArgs>(
      MenuReviewController.new,
    );
