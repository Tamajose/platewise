import '../../../core/data/demo/demo_analysis.dart';
import '../../../core/data/demo/demo_foods.dart';
import '../../../core/data/demo/demo_store.dart';
import '../../../core/data/ids.dart';
import '../../../core/domain/domain.dart';
import '../domain/meal_log_repository.dart';

/// Demo mode: estimates come from a small local catalog and meals are saved to
/// the [DemoStore].
class DemoMealLogRepository implements MealLogRepository {
  DemoMealLogRepository(this._store, {this._generateId = newId});

  final DemoStore _store;
  final IdGenerator _generateId;

  @override
  Future<MealDraft> analyzePhoto(String? imagePath) async {
    throw const Failure(
      'Live photo analysis needs a configured backend. Try a labeled sample or enter the photo’s foods manually.',
      code: 'DEMO_ONLY',
    );
  }

  @override
  Future<MealDraft> analyzeText(
    String description,
    String language, {
    MealSource source = MealSource.text,
  }) async =>
      analyzeDemoText(description, language, id: _generateId(), source: source);

  @override
  Future<SavedMeal> save(MealDraft draft) async {
    SavedMeal? saved;
    await _store.update((state) {
      final existing = state.meals.where((m) => m.id == draft.id).firstOrNull;
      // Saving a new draft twice keeps the first meal.
      if (existing != null && !draft.isSaved) {
        saved = existing;
        return state;
      }
      if (draft.isSaved &&
          (existing == null || existing.updatedAt != draft.expectedUpdatedAt)) {
        throw const Failure('This meal changed. Open it again to edit.');
      }
      final now = DateTime.now().toUtc();
      final meal = SavedMeal(
        draft,
        existing?.at ?? now,
        now.toIso8601String(),
        draft.range.midpoint,
      );
      saved = meal;
      return state.copyWith(
        meals: [...state.meals.where((m) => m.id != draft.id), meal],
      );
    });
    return saved!;
  }

  @override
  Future<String?> imageUrl(String mealId) async => null;

  @override
  MealDraft? sampleDraft() => MealDraft(
    id: _generateId(),
    source: MealSource.photo,
    items: const [DemoFoods.chicken, DemoFoods.dal],
    model: 'demo-fixtures',
    assumptions: const ['Illustrative meal using seeded portions.'],
  );
}
