import '../../../core/data/api/api_client.dart';
import '../../../core/data/ids.dart';
import '../../../core/data/mappers/mappers.dart';
import '../../../core/domain/domain.dart';
import '../domain/meal_log_repository.dart';

class LiveMealLogRepository implements MealLogRepository {
  LiveMealLogRepository(this._api, {this._generateId = newId});

  final ApiClient _api;
  final IdGenerator _generateId;

  @override
  Future<MealDraft> analyzePhoto(String? imagePath) async {
    if (imagePath == null) throw const Failure('Choose a photo first.');
    return mealDraftFromEstimate(
      await _api.call('analyze_photo', {'image_storage_path': imagePath}),
      id: _generateId(),
      source: MealSource.photo,
      imagePath: imagePath,
    );
  }

  @override
  Future<MealDraft> analyzeText(
    String description,
    String language, {
    MealSource source = MealSource.text,
  }) async => mealDraftFromEstimate(
    await _api.call('analyze_text', {
      'description': description,
      'language': language,
    }),
    id: _generateId(),
    source: source,
  );

  @override
  Future<SavedMeal> save(MealDraft draft) async => savedMealFromJson(
    await _api.call(
      draft.isSaved ? 'edit_meal' : 'confirm_meal',
      mealDraftToJson(draft),
    ),
  );

  @override
  Future<String?> imageUrl(String mealId) async =>
      (await _api.call('meal_image_url', {'id': mealId}))['signed_url']
          as String?;

  @override
  MealDraft? sampleDraft() => null;
}
