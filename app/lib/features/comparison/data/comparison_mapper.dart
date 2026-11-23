import '../../../core/data/json.dart';
import '../../../core/data/mappers/mappers.dart';
import '../../../core/domain/domain.dart';
import '../domain/decision.dart';

MenuOption menuOptionFromJson(Json json) => MenuOption(
  json['name'] as String,
  portion: json['portion'] as String?,
  kcal: json['printed_kcal'] as int?,
);

Json menuOptionToJson(MenuOption option) => {
  'name': option.name,
  'portion': option.portion,
  'printed_kcal': option.kcal,
};

Json decisionOptionToJson(DecisionOption option) => option.menu == null
    ? {'kind': 'photo', 'key': option.key, 'image_storage_path': option.path}
    : {
        'kind': 'menu',
        'key': option.key,
        ...menuOptionToJson(option.menu!),
        'language': option.language,
      };

/// Reads the `compare` response. Estimates carry no id, so [newId] supplies
/// one for each draft. [source] is how the options were captured.
DecisionResult decisionResultFromJson(
  Json json, {
  required MealSource source,
  required String Function() newId,
}) => DecisionResult(
  [
    for (final row in jsonRows(json['results']))
      RankedMeal(
        row['key'] as String,
        mealDraftFromEstimate(
          Json.from(row['estimate'] as Map),
          id: newId(),
          source: source,
          imagePath: row['image_storage_path'] as String?,
        ),
        row['rank'] as int,
        budgetFitFromWire(row['fit'] as String),
        row['reason'] as String,
      ),
  ],
  [
    for (final row in jsonRows(json['failures']))
      (
        key: row['key'] as String,
        message: row['message'] as String,
        retryable: row['retryable'] as bool,
      ),
  ],
);
