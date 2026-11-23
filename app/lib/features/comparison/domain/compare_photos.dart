import 'dart:typed_data';

import '../../../core/domain/domain.dart';
import 'comparison_repository.dart';
import 'decision.dart';

/// The most and fewest photos that can be compared.
const maxComparedPhotos = 3;
const minComparedPhotos = 2;

/// The largest meal budget a person can enter, in kcal.
const maxMealBudget = 5000;

const budgetMessage =
    'Enter a meal budget from 1 to $maxMealBudget kcal, or leave it blank.';

/// A meal budget from typed text. Blank means no budget. Throws a [Failure]
/// for anything that is not a whole number from 1 to 5,000.
int? parseMealBudget(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value < 1 || value > maxMealBudget) {
    throw const Failure(budgetMessage);
  }
  return value;
}

/// A dish for the comparison, from typed fields. Returns the dish, or the
/// message to show. A blank portion or calorie field means "not given".
({MenuOption? dish, String? error}) buildMenuOption({
  required String name,
  required String portion,
  required String kcal,
}) {
  if (name.trim().isEmpty) return (dish: null, error: 'Enter a dish name.');
  final printed = kcal.trim().isEmpty ? null : int.tryParse(kcal.trim());
  if (kcal.trim().isNotEmpty &&
      (printed == null || printed < 15 || printed > 6000)) {
    return (dish: null, error: 'Enter 15–6,000 kcal.');
  }
  return (
    dish: MenuOption(
      name.trim(),
      portion: portion.trim().isEmpty ? null : portion.trim(),
      kcal: printed,
    ),
    error: null,
  );
}

/// Uploads up to three photos, estimates them and ranks them for a budget.
///
/// A photo that cannot be uploaded does not stop the others: it is reported as
/// a failure beside the ranked results.
class ComparePhotos {
  ComparePhotos(this._comparison, this._media);

  final ComparisonRepository _comparison;
  final MediaStorage _media;

  /// [photos] holds the chosen photos, with null for an empty slot. [paths]
  /// holds the storage path of each photo already uploaded, so a retry does not
  /// upload it again. It is updated in place, so a caller can delete the
  /// uploads even when this throws. [isOpen] says whether the screen is still
  /// waiting, because photos uploaded after it closed are deleted at once.
  Future<DecisionResult> call({
    required List<Uint8List?> photos,
    required List<String?> paths,
    required int? budget,
    bool Function() isOpen = _always,
  }) async {
    final attempts = await Future.wait([
      for (var i = 0; i < photos.length; i++)
        if (photos[i] != null) _upload(i, photos[i]!, paths, isOpen),
    ]);
    final ready = [
      for (final a in attempts)
        if (a.path != null) DecisionOption.photo(a.key, a.path),
    ];
    final failures = [
      for (final a in attempts)
        if (a.error != null) (key: a.key, message: a.error!, retryable: true),
    ];
    if (ready.length >= minComparedPhotos) {
      final ranked = await _comparison.compare(ready, budget);
      return DecisionResult(ranked.meals, [...ranked.failures, ...failures]);
    }
    if (ready.length == 1) {
      final only = ready.single;
      try {
        final draft = await _comparison.estimatePhoto(only.path);
        final fit = budgetFit(draft.range, budget);
        return DecisionResult([
          RankedMeal(only.key, draft, 1, fit, fitReason(fit)),
        ], failures);
      } on Object catch (e) {
        return DecisionResult(const [], [
          ...failures,
          (key: only.key, message: messageFor(e), retryable: true),
        ]);
      }
    }
    return DecisionResult(const [], failures);
  }

  Future<({String key, String? path, String? error})> _upload(
    int index,
    Uint8List photo,
    List<String?> paths,
    bool Function() isOpen,
  ) async {
    final key = '$index';
    try {
      final path = paths[index] ?? await _media.upload(photo);
      if (!isOpen()) {
        await _discard(path);
        return (key: key, path: null, error: 'Comparison closed.');
      }
      paths[index] = path;
      if (path == null) {
        return (
          key: key,
          path: null,
          error: 'Live photo analysis is unavailable in demo mode.',
        );
      }
      return (key: key, path: path, error: null);
    } on Object catch (e) {
      return (key: key, path: null, error: messageFor(e));
    }
  }

  Future<void> _discard(String? path) async {
    try {
      await _media.discard(path);
    } on Object {
      /* The retention sweep can retry. */
    }
  }
}

bool _always() => true;
