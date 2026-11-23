import '../../../core/domain/meal.dart';
import 'nearby_meal.dart';
import 'restaurant.dart';

/// Finds restaurants around a point.
abstract interface class RestaurantSearch {
  /// Throws a `Failure` for an invalid point or radius, or when no source
  /// could answer.
  Future<List<NearbyRestaurant>> search(GeoPoint point, double radiusKm);
}

/// The device's current location.
abstract interface class LocationService {
  /// Throws a `Failure` that tells the person what to do instead when
  /// location is off, denied or cannot be found.
  Future<GeoPoint> current();
}

/// Meals from seeded menus, for trying the app.
abstract interface class NearbyRepository {
  Future<List<NearbyMeal>> sampleMeals(
    GeoPoint point,
    double radiusKm,
    int? budget,
  );
}

/// A draft for logging [meal], marked as illustrative.
MealDraft draftForNearbyMeal(NearbyMeal meal, String id) => MealDraft(
  id: id,
  source: MealSource.nearby,
  items: [meal.food],
  model: 'demo-fixtures',
  assumptions: [
    '${meal.portion} · ${meal.restaurant}',
    'Illustrative seeded menu. Availability and nutrition are unverified.',
  ],
);
