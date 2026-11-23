import '../../domain/domain.dart';
import '../json.dart';

FoodItem foodItemFromJson(Json json) => FoodItem(
  name: json['name'] as String,
  quantity: (json['quantity'] as num).toDouble(),
  unit: json['unit'] as String,
  range: CalorieRange(json['calorie_low'] as int, json['calorie_high'] as int),
  grams: (json['estimated_grams'] as num?)?.toDouble(),
  nutrients: {
    for (final n in Nutrient.values) n: (json[n.key] as num?)?.toDouble(),
  },
  reference: json['normalized_food_reference'] as String?,
  nutrientSource: json['nutrient_source'] as String? ?? 'unavailable',
  provenance: json['provenance'] as String? ?? 'manual',
);

Json foodItemToJson(FoodItem item) => {
  'name': item.name,
  'quantity': item.quantity,
  'unit': item.unit,
  'calorie_low': item.range.low,
  'calorie_high': item.range.high,
  'estimated_grams': item.grams,
  'normalized_food_reference': item.reference,
  for (final n in Nutrient.values) n.key: item.nutrients[n],
  'nutrient_source': item.nutrientSource,
  'provenance': item.provenance,
};
