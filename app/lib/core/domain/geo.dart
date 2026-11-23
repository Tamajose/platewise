import 'dart:math' as math;

/// Great-circle distance in kilometres between two coordinates.
double distanceKm(double aLat, double aLon, double bLat, double bLon) {
  const rad = math.pi / 180;
  final a =
      math.pow(math.sin((bLat - aLat) * rad / 2), 2) +
      math.cos(aLat * rad) *
          math.cos(bLat * rad) *
          math.pow(math.sin((bLon - aLon) * rad / 2), 2);
  return 6371 * 2 * math.asin(math.sqrt(math.min(1, a)));
}
