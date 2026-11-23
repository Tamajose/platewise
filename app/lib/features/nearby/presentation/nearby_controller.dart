import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/failure_message.dart';
import '../data/nearby_providers.dart';
import '../domain/restaurant.dart';

class NearbyState {
  const NearbyState({
    this.point,
    this.area,
    this.radius = 3,
    this.query = '',
    this.showMap = false,
    this.showSamples = false,
    this.loading = false,
    this.locating = false,
    this.restaurants,
    this.locationError,
    this.searchError,
  });

  final GeoPoint? point;

  /// The name of the chosen area, `Current location`, or null for a custom pin.
  final String? area;
  final double radius;
  final String query;
  final bool showMap, showSamples, loading, locating;

  /// The last search result, or null before any search.
  final List<NearbyRestaurant>? restaurants;
  final String? locationError, searchError;

  bool get busy => loading || locating;

  /// The restaurants that match the typed query, best match first.
  List<NearbyRestaurant> get matches =>
      rankRestaurants(restaurants ?? const [], query);

  NearbyState copyWith({
    GeoPoint? point,
    String? area,
    double? radius,
    String? query,
    bool? showMap,
    bool? showSamples,
    bool? loading,
    bool? locating,
    List<NearbyRestaurant>? restaurants,
    String? locationError,
    String? searchError,
    bool clearArea = false,
    bool clearResults = false,
    bool clearErrors = false,
  }) => NearbyState(
    point: point ?? this.point,
    area: clearArea ? null : area ?? this.area,
    radius: radius ?? this.radius,
    query: query ?? this.query,
    showMap: showMap ?? this.showMap,
    showSamples: showSamples ?? this.showSamples,
    loading: loading ?? this.loading,
    locating: locating ?? this.locating,
    restaurants: clearResults ? null : restaurants ?? this.restaurants,
    locationError: clearErrors ? null : locationError ?? this.locationError,
    searchError: clearErrors ? null : searchError ?? this.searchError,
  );
}

/// State of the Nearby screen: where to search, how far, and what was found.
class NearbyController extends Notifier<NearbyState> {
  @override
  NearbyState build() => const NearbyState();

  /// Chooses the search point. Clears the previous results.
  void select(GeoPoint point, {String? label}) {
    state = state.copyWith(
      point: point,
      area: label,
      clearArea: label == null,
      clearResults: true,
      clearErrors: true,
    );
  }

  void setRadius(double radius) => state = state.copyWith(
    radius: radius,
    clearResults: true,
    clearErrors: true,
  );

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleMap() => state = state.copyWith(showMap: !state.showMap);

  void toggleSamples() =>
      state = state.copyWith(showSamples: !state.showSamples);

  /// Finds the device location, selects it and searches there.
  Future<void> locate() async {
    if (state.busy) return;
    state = state.copyWith(locating: true, clearErrors: true);
    final GeoPoint here;
    try {
      here = await ref.read(locationServiceProvider).current();
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          locating: false,
          locationError: failureMessage(e),
        );
      }
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(locating: false);
    select(here, label: 'Current location');
    await search();
  }

  Future<void> search() async {
    final point = state.point;
    if (point == null || state.busy) return;
    state = state.copyWith(
      loading: true,
      clearResults: true,
      clearErrors: true,
    );
    try {
      final rows = await ref
          .read(restaurantSearchProvider)
          .search(point, state.radius);
      if (ref.mounted) {
        state = state.copyWith(loading: false, restaurants: rows);
      }
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, searchError: failureMessage(e));
      }
    }
  }
}

final nearbyControllerProvider =
    NotifierProvider.autoDispose<NearbyController, NearbyState>(
      NearbyController.new,
    );
