import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../core/data/core_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/restaurant.dart';
import 'coordinates_dialog.dart';
import 'nearby_controller.dart';
import 'sample_menus.dart';
import 'search_map.dart';

/// Find restaurants around a chosen area, and in demo mode browse sample menus.
class NearbyScreen extends ConsumerWidget {
  const NearbyScreen({super.key});

  Future<void> enterCoordinates(BuildContext context, WidgetRef ref) async {
    final state = ref.read(nearbyControllerProvider);
    final chosen = await showDialog<GeoPoint>(
      context: context,
      builder: (_) => CoordinatesDialog(state.point ?? searchAreas.first.point),
    );
    if (chosen != null && context.mounted) {
      ref.read(nearbyControllerProvider.notifier).select(chosen);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyControllerProvider);
    final controller = ref.read(nearbyControllerProvider.notifier);
    final config = ref.watch(configProvider);
    final pin = state.point;
    final matches = state.matches;
    final visible = matches.take(24).toList();
    final restaurants = state.restaurants;
    return PageScroll(
      maxWidth: 1080,
      children: [
        const PageHeading(
          'Nearby',
          detail:
              'Find live restaurant listings around your selected location.',
        ),
        const SizedBox(height: 18),
        AdaptiveColumns(
          primaryFlex: 2,
          secondaryFlex: 3,
          primary: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Search area'),
                const SizedBox(height: 12),
                PrimaryButton(
                  state.locating ? 'Locating…' : 'Use my location',
                  icon: Icons.my_location_rounded,
                  busy: state.locating,
                  onPressed: state.busy ? null : controller.locate,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey(state.area),
                  initialValue: searchAreas.any((a) => a.name == state.area)
                      ? state.area
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select a location',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  hint: Text(
                    state.area ??
                        (pin == null ? 'Choose an area' : 'Custom map point'),
                  ),
                  items: [
                    for (final area in searchAreas)
                      DropdownMenuItem(
                        value: area.name,
                        child: Text(area.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: state.busy
                      ? null
                      : (name) {
                          if (name == null) return;
                          controller.select(
                            searchAreas.firstWhere((a) => a.name == name).point,
                            label: name,
                          );
                        },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Radius ${state.radius.toStringAsFixed(0)} km'),
                    Expanded(
                      child: Slider(
                        value: state.radius,
                        min: 1,
                        max: maxNearbyRadiusKm,
                        divisions: maxNearbyRadiusKm.toInt() - 1,
                        label: '${state.radius.toStringAsFixed(0)} km',
                        onChanged: state.busy ? null : controller.setRadius,
                      ),
                    ),
                  ],
                ),
                SecondaryButton(
                  'Search this area',
                  icon: Icons.search,
                  onPressed: state.busy || pin == null
                      ? null
                      : controller.search,
                ),
                if (state.locationError != null) ...[
                  const SizedBox(height: 8),
                  ErrorState(state.locationError!, retry: controller.locate),
                ],
                if (state.searchError != null) ...[
                  const SizedBox(height: 8),
                  ErrorState(state.searchError!, retry: controller.search),
                ],
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => enterCoordinates(context, ref),
                  child: const Text('Enter coordinates'),
                ),
              ],
            ),
          ),
          secondary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Restaurant or cuisine',
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.done,
                onChanged: controller.setQuery,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (state.showMap)
                    Expanded(
                      child: Text(
                        'Tap the map to set your pin',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton.icon(
                    onPressed: controller.toggleMap,
                    icon: Icon(
                      state.showMap
                          ? Icons.view_list_outlined
                          : Icons.map_outlined,
                    ),
                    label: Text(state.showMap ? 'List view' : 'Map view'),
                  ),
                ],
              ),
              if (state.showMap) ...[
                SearchMap(
                  point: pin,
                  radius: state.radius,
                  places: visible,
                  useTiles: config.protectedMapTiles,
                  enabled: !state.busy,
                  onPick: controller.select,
                ),
                const SizedBox(height: 12),
              ],
              if (!state.loading &&
                  restaurants == null &&
                  state.searchError == null &&
                  state.locationError == null)
                const EmptyState(
                  'Choose a search area',
                  'Use your current location, select an area, or set a pin on the map.',
                  icon: Icons.place_outlined,
                ),
              if (state.loading)
                const LoadingState('Finding nearby restaurants…'),
              if (restaurants != null) ...[
                const SizedBox(height: 14),
                SectionTitle(
                  'Nearby restaurants',
                  detail: matches.length > visible.length
                      ? 'Showing ${visible.length} of ${matches.length} matches'
                      : null,
                ),
                const SizedBox(height: 7),
                if (restaurants.isEmpty)
                  const EmptyState(
                    'No restaurants found',
                    'Try a larger radius or a different location.',
                    icon: Icons.location_off_outlined,
                  )
                else if (matches.isEmpty)
                  const EmptyState(
                    'No matches',
                    'Try another restaurant name or cuisine.',
                    icon: Icons.search_off_outlined,
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => ref.read(urlOpenerProvider)(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                    child: const Text('© OpenStreetMap contributors'),
                  ),
                ),
                for (final place in visible) ...[
                  _RestaurantCard(place),
                  const SizedBox(height: 9),
                ],
              ],
              if (config.demo) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: controller.toggleSamples,
                  child: Text(
                    state.showSamples ? 'Hide sample menus' : 'Sample menus',
                  ),
                ),
                if (state.showSamples)
                  SampleMenus(
                    point: pin ?? searchAreas.first.point,
                    radius: state.radius,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RestaurantCard extends ConsumerWidget {
  const _RestaurantCard(this.place);
  final NearbyRestaurant place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = place.distanceKm < 1
        ? '${(place.distanceKm * 1000).round()} m'
        : '${place.distanceKm.toStringAsFixed(1)} km';
    final description = place.cuisine.isEmpty ? place.category : place.cuisine;
    return Surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(Icons.restaurant_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('$description · $distance'),
                TextButton.icon(
                  onPressed: () async {
                    final opened = await ref.read(urlOpenerProvider)(
                      place.directions,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Directions could not be opened.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Directions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
