import 'package:geolocator/geolocator.dart';

import '../../../core/domain/failure.dart';
import '../domain/nearby_services.dart';
import '../domain/restaurant.dart';

/// Reads the device location with the `geolocator` plugin.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoPoint> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const Failure(
          'Location services are unavailable. Select an area or enter coordinates.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const Failure(
          'Location permission was denied. Select a place or tap the map.',
        );
      }
      final here = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return GeoPoint(here.latitude, here.longitude);
    } on Failure {
      rethrow;
    } on Object {
      throw const Failure(
        'Current location could not be found. Select a place or tap the map.',
      );
    }
  }
}
