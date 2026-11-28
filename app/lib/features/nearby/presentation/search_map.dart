import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/restaurant.dart';
import '../../../core/l10n/l10n.dart';

LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);

/// A map for choosing the search point by tapping, with the search radius and
/// the restaurants found. Real tiles load only when the build enables them;
/// otherwise a schematic grid stands in.
class SearchMap extends StatefulWidget {
  const SearchMap({
    super.key,
    required this.point,
    required this.radius,
    required this.places,
    required this.useTiles,
    required this.enabled,
    required this.onPick,
  });

  final GeoPoint? point;
  final double radius;
  final List<NearbyRestaurant> places;
  final bool useTiles, enabled;
  final void Function(GeoPoint) onPick;

  @override
  State<SearchMap> createState() => _SearchMapState();
}

class _SearchMapState extends State<SearchMap> {
  final controller = MapController();
  bool ready = false;

  @override
  void didUpdateWidget(SearchMap old) {
    super.didUpdateWidget(old);
    final point = widget.point;
    // Re-centre when the point changed from outside, not by tapping the map.
    if (ready && point != null && point != old.point && !_tapped) {
      controller.move(_latLng(point), 13.5);
    }
    _tapped = false;
  }

  bool _tapped = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.point;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 235,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: _latLng(pin ?? searchAreas.first.point),
            initialZoom: 13.5,
            minZoom: 5,
            maxZoom: 18,
            backgroundColor: const Color(0xFFE8EEE2),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: widget.enabled
                ? (_, where) {
                    _tapped = true;
                    widget.onPick(GeoPoint(where.latitude, where.longitude));
                  }
                : null,
            onMapReady: () => ready = true,
          ),
          children: [
            if (widget.useTiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: kIsWeb
                    ? 'unknown'
                    : 'com.platewise.platewise',
                maxNativeZoom: 19,
              )
            else
              const _SchematicGrid(),
            if (pin != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _latLng(pin),
                    radius: widget.radius * 1000,
                    useRadiusInMeter: true,
                    color: PlateColors.forest.withValues(alpha: .12),
                    borderColor: PlateColors.forest.withValues(alpha: .55),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final place in widget.places)
                  Marker(
                    point: _latLng(place.point),
                    width: 46,
                    height: 46,
                    child: Tooltip(
                      message: place.name,
                      child: const IconTile(
                        Icons.restaurant,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (pin != null)
                  Marker(
                    point: _latLng(pin),
                    width: 45,
                    height: 45,
                    child: Icon(
                      Icons.location_on,
                      color: PlateColors.deep,
                      size: 42,
                      semanticLabel: context.tr('Selected location'),
                    ),
                  ),
              ],
            ),
            if (widget.useTiles)
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(5),
                  child: IndicatorTag(
                    context.tr('Schematic pin map'),
                    background: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SchematicGrid extends StatelessWidget {
  const _SchematicGrid();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lines = Paint()
      ..color = const Color(0xFFC9D8C8)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 29) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), lines);
    }
    for (double y = 0; y < size.height; y += 29) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lines);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
