import '../../../core/domain/domain.dart';

class NearbyMeal {
  const NearbyMeal({
    required this.id,
    required this.restaurantId,
    required this.restaurant,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.portion,
    required this.range,
    required this.nutrients,
    required this.distance,
    required this.fit,
  });
  final String id, restaurantId, restaurant, name, portion;
  final double latitude, longitude, distance;
  final CalorieRange range;
  final Map<Nutrient, double?> nutrients;
  final BudgetFit fit;
  FoodItem get food => FoodItem(
    name: name,
    quantity: 1,
    unit: 'serving',
    range: range,
    nutrients: nutrients,
    provenance: 'demo',
    nutrientSource: nutrients.values.any((v) => v != null)
        ? 'seeded'
        : 'unavailable',
  );
}
