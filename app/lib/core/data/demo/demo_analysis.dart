import '../../domain/domain.dart';
import 'demo_foods.dart';

/// Estimates a meal from a description using the demo catalog, as demo mode's
/// stand-in for the AI service.
///
/// Throws a [Failure] for Bangla, which the catalog does not cover, and for a
/// description that matches no catalog food.
MealDraft analyzeDemoText(
  String description,
  String language, {
  required String id,
  MealSource source = MealSource.text,
}) {
  if (language == 'bn') {
    throw const Failure(
      'Bangla analysis is unavailable in this demo. You can still add Bangla item names manually.',
      code: 'LANGUAGE_UNAVAILABLE',
    );
  }
  final lower = description.toLowerCase();
  final matches = DemoFoods.catalog
      .where((entry) => entry.keys.any(lower.contains))
      .map((entry) => entry.food)
      .toList();
  if (matches.isEmpty) {
    throw const Failure(
      'This demo recognizes a small set of foods. Try “rice and dal” or enter your meal manually.',
      code: 'DEMO_NO_MATCH',
    );
  }
  return MealDraft(
    id: id,
    source: source,
    items: matches,
    model: 'demo-fixtures',
    assumptions: const [
      'Illustrative reference portions from the demo catalog. Review quantities before saving.',
    ],
  );
}
