import '../../../core/domain/meal.dart';

/// Turns what a person gives us (a photo, a description) into a meal draft, and
/// saves confirmed drafts to the log.
abstract interface class MealLogRepository {
  /// Estimates a meal from a photo already stored at [imagePath].
  Future<MealDraft> analyzePhoto(String? imagePath);

  /// Estimates a meal from [description], written in [language] (`en` or `bn`).
  /// [source] records how the description was captured.
  Future<MealDraft> analyzeText(
    String description,
    String language, {
    MealSource source = MealSource.text,
  });

  /// Adds a new meal to the log, or updates it when [draft] was saved before.
  /// Throws a `Failure` when a saved meal changed since the draft was opened.
  Future<SavedMeal> save(MealDraft draft);

  /// A temporary link to the photo of a saved meal, or null when it has none.
  Future<String?> imageUrl(String mealId);

  /// A ready-made illustrative draft for trying the app, or null when this
  /// build offers none.
  MealDraft? sampleDraft();
}
