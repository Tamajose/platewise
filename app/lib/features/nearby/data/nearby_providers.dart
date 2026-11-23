import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/nearby_services.dart';

/// Overridden by the composition root.
final restaurantSearchProvider = Provider<RestaurantSearch>(
  (ref) => throw StateError('Restaurant search initialization required'),
);

/// Overridden by the composition root.
final locationServiceProvider = Provider<LocationService>(
  (ref) => throw StateError('Location service initialization required'),
);

/// Overridden by the composition root with the demo or live implementation.
final nearbyRepositoryProvider = Provider<NearbyRepository>(
  (ref) => throw StateError('Nearby repository initialization required'),
);
