import '../../../core/data/api/api_client.dart';
import '../../../core/data/ids.dart';
import '../../../core/data/json.dart';
import '../../../core/data/mappers/mappers.dart';
import '../../../core/domain/domain.dart';
import '../domain/comparison_repository.dart';
import '../domain/decision.dart';
import 'comparison_mapper.dart';

class LiveComparisonRepository implements ComparisonRepository {
  LiveComparisonRepository(this._api, {this._generateId = newId});

  final ApiClient _api;
  final IdGenerator _generateId;

  @override
  Future<List<MenuOption>> extractMenu(String? imagePath) async {
    if (imagePath == null) throw const Failure('Choose a menu photo first.');
    final data = await _api.call('extract_menu', {
      'image_storage_path': imagePath,
    });
    return jsonRows(data['options']).map(menuOptionFromJson).toList();
  }

  @override
  Future<DecisionResult> compare(
    List<DecisionOption> options,
    int? budget,
  ) async => decisionResultFromJson(
    await _api.call('compare', {
      'options': options.map(decisionOptionToJson).toList(),
      'budget': budget,
    }),
    source: options.first.menu != null
        ? MealSource.menu
        : MealSource.comparison,
    newId: _generateId,
  );

  @override
  Future<MealDraft> estimatePhoto(String? imagePath) async {
    if (imagePath == null) throw const Failure('Choose a photo first.');
    return mealDraftFromEstimate(
      await _api.call('analyze_photo', {'image_storage_path': imagePath}),
      id: _generateId(),
      source: MealSource.photo,
      imagePath: imagePath,
    );
  }

  @override
  List<MenuOption>? sampleMenu() => null;
}
