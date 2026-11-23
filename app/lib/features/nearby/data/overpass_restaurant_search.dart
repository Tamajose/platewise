import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../../core/domain/failure.dart';
import '../domain/nearby_services.dart';
import '../domain/restaurant.dart';

const _amenities = {
  'restaurant': 'Restaurant',
  'fast_food': 'Fast food',
  'cafe': 'Café',
};

/// Searches OpenStreetMap through public Overpass servers, falling back to a
/// second server when the first fails.
class OverpassRestaurantSearch implements RestaurantSearch {
  OverpassRestaurantSearch(this._client);

  final http.Client _client;

  @override
  Future<List<NearbyRestaurant>> search(GeoPoint point, double radiusKm) async {
    if (!point.isValid ||
        !radiusKm.isFinite ||
        radiusKm < 1 ||
        radiusKm > maxNearbyRadiusKm) {
      throw const Failure('Select a valid location and search radius.');
    }
    // Allow for rounding of the search center. The final radius uses the
    // original pin.
    final meters = (radiusKm * 1000).round() + 100;
    final latitude = point.latitude.toStringAsFixed(3);
    final longitude = point.longitude.toStringAsFixed(3);
    final query =
        '[out:json][timeout:10];'
        'nwr["amenity"~"^(restaurant|fast_food|cafe)\$"]["name"]'
        '(around:$meters,$latitude,$longitude);out center;';
    // The public Asia mirror covers the pilot areas and their neighbors.
    final useAsia =
        point.latitude >= 5 &&
        point.latitude <= 38 &&
        point.longitude >= 60 &&
        point.longitude <= 100;
    final endpoints = [
      if (useAsia) Uri.https('ovp.dresel.systems', '/api-as/interpreter'),
      Uri.https('overpass-api.de', '/api/interpreter'),
      if (!useAsia) Uri.https('overpass.private.coffee', '/api/interpreter'),
    ];
    for (final endpoint in endpoints) {
      try {
        final response = await _query(endpoint, query);
        if (response.statusCode != 200) continue;
        return parseRestaurants(response.bodyBytes, point, radiusKm);
      } on Exception {
        // Another Overpass instance can serve the same public dataset.
        continue;
      }
    }
    throw const Failure(
      'Live restaurant search is unavailable. Try again or reduce the radius.',
      code: 'RESTAURANT_SEARCH_UNAVAILABLE',
      retryable: true,
    );
  }

  Future<http.Response> _query(Uri endpoint, String query) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest('POST', endpoint, abortTrigger: abort.future)
          ..headers['Accept'] = 'application/json'
          ..bodyFields = {'data': query};
    if (!kIsWeb) request.headers['User-Agent'] = 'PlateWise/1.0';
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            abort.complete();
            throw TimeoutException('Restaurant search timed out.');
          },
        );
  }
}

/// Reads an Overpass response into restaurants within [radiusKm] of
/// [origin]. Throws a [FormatException] for an incomplete response, so the
/// caller can try another server.
List<NearbyRestaurant> parseRestaurants(
  List<int> bytes,
  GeoPoint origin,
  double radiusKm,
) {
  final data = jsonDecode(utf8.decode(bytes));
  if (data is! Map || data['elements'] is! List || data['remark'] != null) {
    throw const FormatException('Incomplete restaurant response.');
  }
  final restaurants = <String, NearbyRestaurant>{};
  for (final item in data['elements'] as List) {
    if (item is! Map || item['tags'] is! Map) continue;
    final tags = item['tags'] as Map;
    final name = tags['name'];
    final category = _amenities[tags['amenity']];
    final type = item['type'];
    final id = item['id'];
    if (name is! String ||
        name.trim().isEmpty ||
        category == null ||
        !['node', 'way', 'relation'].contains(type) ||
        id is! int ||
        id <= 0) {
      continue;
    }
    final coordinates = item['center'] is Map ? item['center'] as Map : item;
    final lat = coordinates['lat'];
    final lon = coordinates['lon'];
    if (lat is! num || lon is! num) continue;
    final point = GeoPoint(lat.toDouble(), lon.toDouble());
    if (!point.isValid) continue;
    final distance = origin.distanceTo(point);
    if (distance > radiusKm) continue;
    final cuisine = tags['cuisine'];
    final placeId = '$type/$id';
    restaurants[placeId] = NearbyRestaurant(
      id: placeId,
      name: name.trim(),
      category: category,
      cuisine: cuisine is String
          ? cuisine
                .split(';')
                .map((part) => part.replaceAll('_', ' ').trim())
                .where((part) => part.isNotEmpty)
                .join(', ')
          : '',
      point: point,
      distanceKm: distance,
    );
  }
  return restaurants.values.toList();
}
