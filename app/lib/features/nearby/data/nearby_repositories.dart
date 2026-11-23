import 'dart:convert';

import '../../../core/data/api/api_client.dart';
import '../../../core/data/json.dart';
import '../../../core/data/mappers/mappers.dart';
import '../../../core/domain/domain.dart';
import '../domain/nearby_meal.dart';
import '../domain/nearby_services.dart';
import '../domain/restaurant.dart';

/// Meals from the service's seeded menus.
class LiveNearbyRepository implements NearbyRepository {
  LiveNearbyRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<NearbyMeal>> sampleMeals(
    GeoPoint point,
    double radiusKm,
    int? budget,
  ) async {
    final data = await _api.call('nearby', {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'radius_km': radiusKm,
      'budget': budget,
    });
    return jsonRows(data['options']).map(nearbyMealFromJson).toList();
  }
}

NearbyMeal nearbyMealFromJson(Json row) {
  final venue = row['restaurant'] as Map;
  return NearbyMeal(
    id: row['id'] as String,
    restaurantId: venue['id'] as String,
    restaurant: venue['name'] as String,
    name: row['name'] as String,
    latitude: (venue['latitude'] as num).toDouble(),
    longitude: (venue['longitude'] as num).toDouble(),
    portion: row['portion'] as String,
    range: CalorieRange(row['calorie_low'] as int, row['calorie_high'] as int),
    nutrients: {
      for (final n in Nutrient.values) n: (row[n.key] as num?)?.toDouble(),
    },
    distance: (row['distance_km'] as num).toDouble(),
    fit: budgetFitFromWire(row['fit'] as String),
  );
}

/// Demo mode reads the menus bundled with the app.
class DemoNearbyRepository implements NearbyRepository {
  DemoNearbyRepository(this._loadSeed);

  /// Returns the text of the bundled `seeded_menus.json`.
  final Future<String> Function() _loadSeed;

  @override
  Future<List<NearbyMeal>> sampleMeals(
    GeoPoint point,
    double radiusKm,
    int? budget,
  ) async {
    final venues = jsonRows(jsonDecode(await _loadSeed()));
    final items = <NearbyMeal>[];
    for (final venue in venues) {
      final spot = GeoPoint(
        (venue['latitude'] as num).toDouble(),
        (venue['longitude'] as num).toDouble(),
      );
      final distance = point.distanceTo(spot);
      if (distance > radiusKm) continue;
      for (final food in jsonRows(venue['menu'])) {
        final range = CalorieRange(
          food['calorie_low'] as int,
          food['calorie_high'] as int,
        );
        items.add(
          NearbyMeal(
            id: food['id'] as String,
            restaurantId: venue['id'] as String,
            restaurant: venue['name'] as String,
            latitude: spot.latitude,
            longitude: spot.longitude,
            name: food['name'] as String,
            portion: food['portion'] as String,
            range: range,
            nutrients: {
              for (final n in Nutrient.values)
                n: (food[n.key] as num?)?.toDouble(),
            },
            distance: distance,
            fit: budgetFit(range, budget),
          ),
        );
      }
    }
    return items..sort((a, b) {
      final fits = compareFit(
        a.range,
        Confidence.low,
        b.range,
        Confidence.low,
        budget,
      );
      if (fits != 0) return fits;
      final byDistance = a.distance.compareTo(b.distance);
      return byDistance != 0 ? byDistance : a.id.compareTo(b.id);
    });
  }
}
