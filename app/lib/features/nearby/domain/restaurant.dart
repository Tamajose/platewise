import '../../../core/domain/geo.dart';

/// The farthest search radius, in kilometres.
const maxNearbyRadiusKm = 25.0;

/// A place on Earth. Valid when both parts are finite and in range.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude, longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  double distanceTo(GeoPoint other) =>
      distanceKm(latitude, longitude, other.latitude, other.longitude);
}

/// A named search area people can pick without sharing their location.
const searchAreas = [
  (name: 'Cumilla Town Hall', point: GeoPoint(23.4607, 91.1809)),
  (name: 'University of Cumilla area', point: GeoPoint(23.4243, 91.1386)),
  (name: 'Dhaka Dhanmondi', point: GeoPoint(23.746, 90.376)),
];

class NearbyRestaurant {
  const NearbyRestaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.cuisine,
    required this.point,
    required this.distanceKm,
  });

  final String id, name, category, cuisine;
  final GeoPoint point;
  final double distanceKm;

  Uri get directions => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${point.latitude},${point.longitude}',
  });
}

final _wordSeparator = RegExp(r'[\s,;_-]+');

String _searchText(String text) =>
    text.toLowerCase().replaceAll(_wordSeparator, ' ').trim();

/// Restaurants matching every word of [query] in their name, cuisine or
/// category. Exact matches come first, then prefix matches, then the rest;
/// ties go to the nearer place.
List<NearbyRestaurant> rankRestaurants(
  Iterable<NearbyRestaurant> restaurants,
  String query,
) {
  final term = _searchText(query);
  final words = term.split(' ');
  final matches = <({NearbyRestaurant place, int relevance})>[];
  for (final place in restaurants) {
    final name = _searchText(place.name);
    final cuisine = _searchText(place.cuisine);
    final description = '$name $cuisine ${_searchText(place.category)}';
    if (!words.every(description.contains)) continue;
    final relevance = term.isEmpty || name == term || cuisine == term
        ? 0
        : name.startsWith(term) || cuisine.startsWith(term)
        ? 1
        : 2;
    matches.add((place: place, relevance: relevance));
  }
  matches.sort((a, b) {
    final relevance = a.relevance.compareTo(b.relevance);
    if (relevance != 0) return relevance;
    final distance = a.place.distanceKm.compareTo(b.place.distanceKm);
    return distance != 0 ? distance : a.place.id.compareTo(b.place.id);
  });
  return [for (final match in matches) match.place];
}
