import '../../../core/domain/meal.dart';
import 'decision.dart';

/// Estimates and ranks meals a person is choosing between.
abstract interface class ComparisonRepository {
  /// Reads the dishes from a photographed menu stored at [imagePath].
  Future<List<MenuOption>> extractMenu(String? imagePath);

  /// Estimates every option and ranks them for [budget]. An option that cannot
  /// be estimated is reported in the result's failures, not thrown.
  Future<DecisionResult> compare(List<DecisionOption> options, int? budget);

  /// Estimates one stored photo. Used when only one of several photos could
  /// be uploaded.
  Future<MealDraft> estimatePhoto(String? imagePath);

  /// A ready-made menu for trying the app, or null when this build offers none.
  List<MenuOption>? sampleMenu();
}
