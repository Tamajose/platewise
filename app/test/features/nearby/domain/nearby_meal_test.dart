import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/nearby/domain/nearby_meal.dart';

NearbyMeal meal(Map<Nutrient, double?> nutrients) => NearbyMeal(
  id: 'i',
  restaurantId: 'r',
  restaurant: 'Banyan Canteen',
  name: 'Dal bowl',
  latitude: 23.45,
  longitude: 91.18,
  portion: '1 bowl',
  range: const CalorieRange(300, 400),
  nutrients: nutrients,
  distance: 0.4,
  fit: BudgetFit.fits,
);

void main() {
  test('a nearby meal becomes one serving with seeded nutrients', () {
    final food = meal({Nutrient.protein: 12}).food;
    expect(food.name, 'Dal bowl');
    expect(food.unit, 'serving');
    expect(food.quantity, 1);
    expect(food.range.high, 400);
    expect(food.nutrientSource, 'seeded');
    expect(food.provenance, 'demo');
  });

  test('without any nutrient values the source is unavailable', () {
    expect(meal({Nutrient.fat: null}).food.nutrientSource, 'unavailable');
    expect(meal(const {}).food.nutrientSource, 'unavailable');
  });
}
