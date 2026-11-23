import 'calorie_range.dart';
import 'food_item.dart';

enum MealSource {
  photo('Photo'),
  text('Typed description'),
  voice('Voice transcript'),
  menu('Menu'),
  comparison('Comparison'),
  manual('Manual entry'),
  nearby('Nearby menu');

  const MealSource(this.label);
  final String label;
}

enum Confidence { low, medium, high }

class MealDraft {
  const MealDraft({
    required this.id,
    required this.source,
    required this.items,
    this.confidence = Confidence.low,
    this.assumptions = const [],
    this.imagePath,
    this.model,
    this.question,
    this.edited = false,
    this.expectedUpdatedAt,
  });
  final String id;
  final MealSource source;
  final List<FoodItem> items;
  final Confidence confidence;
  final List<String> assumptions;
  final String? imagePath, model, question, expectedUpdatedAt;
  final bool edited;
  bool get isSaved => expectedUpdatedAt != null;
  CalorieRange get range =>
      items.fold(CalorieRange.zero, (sum, i) => sum + i.range);
  String get title =>
      items.isEmpty ? 'Meal draft' : items.map((i) => i.name).join(' · ');
  MealDraft revise(List<FoodItem> next) => MealDraft(
    id: id,
    source: source,
    items: next,
    confidence: Confidence.low,
    assumptions: assumptions,
    imagePath: imagePath,
    model: model,
    question: question,
    edited: true,
    expectedUpdatedAt: expectedUpdatedAt,
  );
  MealDraft choose(MealSource source) => MealDraft(
    id: id,
    source: source,
    items: items,
    confidence: confidence,
    assumptions: assumptions,
    imagePath: imagePath,
    model: model,
    question: question,
    edited: edited,
  );
}

class SavedMeal {
  const SavedMeal(this.draft, this.at, this.updatedAt, this.representative);
  final MealDraft draft;
  final DateTime at;
  final String updatedAt;
  final int representative;
  String get id => draft.id;
  CalorieRange get range => draft.range;
  MealDraft get editable => MealDraft(
    id: draft.id,
    source: draft.source,
    items: draft.items,
    confidence: draft.confidence,
    assumptions: draft.assumptions,
    imagePath: draft.imagePath,
    model: draft.model,
    edited: draft.edited,
    expectedUpdatedAt: updatedAt,
  );
}
