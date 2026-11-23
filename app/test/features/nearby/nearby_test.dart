import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/core/config/app_config.dart';
import 'package:platewise/core/config/app_config_provider.dart';
import 'package:platewise/core/data/core_providers.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/theme/plate_theme.dart';
import 'package:platewise/features/nearby/data/nearby_providers.dart';
import 'package:platewise/features/nearby/data/nearby_repositories.dart';
import 'package:platewise/features/nearby/data/overpass_restaurant_search.dart';
import 'package:platewise/features/nearby/domain/nearby_meal.dart';
import 'package:platewise/features/nearby/domain/nearby_services.dart';
import 'package:platewise/features/nearby/domain/restaurant.dart';
import 'package:platewise/features/nearby/presentation/nearby_controller.dart';
import 'package:platewise/features/nearby/presentation/nearby_screen.dart';

import '../meal_logging/fakes.dart';

const here = GeoPoint(23.4607, 91.1809);

NearbyRestaurant place(
  String id,
  String name,
  double km, {
  String cuisine = '',
  String category = 'Restaurant',
}) => NearbyRestaurant(
  id: id,
  name: name,
  category: category,
  cuisine: cuisine,
  point: here,
  distanceKm: km,
);

List<int> overpass(List<Map<String, Object?>> elements) =>
    utf8.encode(jsonEncode({'elements': elements}));

class FakeSearch implements RestaurantSearch {
  List<NearbyRestaurant> rows = [
    place('node/1', 'Banyan', 0.5, cuisine: 'bengali'),
  ];
  Object? error;
  final searched = <(GeoPoint, double)>[];
  @override
  Future<List<NearbyRestaurant>> search(GeoPoint point, double radiusKm) async {
    searched.add((point, radiusKm));
    if (error != null) throw error!;
    return rows;
  }
}

class FakeLocation implements LocationService {
  Object? error;
  @override
  Future<GeoPoint> current() async {
    if (error != null) throw error!;
    return here;
  }
}

class FakeNearby implements NearbyRepository {
  @override
  Future<List<NearbyMeal>> sampleMeals(
    GeoPoint point,
    double radiusKm,
    int? budget,
  ) async => [];
}

void main() {
  setUpAll(() {});

  group('ranking', () {
    final all = [
      place('3', 'Chicken House', 2, cuisine: 'chicken'),
      place('1', 'Bengali Kitchen', 1, cuisine: 'bengali'),
      place('2', 'Cafe Bengali', 0.5, category: 'Café'),
    ];

    test('no query keeps everyone, nearest first', () {
      expect(rankRestaurants(all, '').map((p) => p.id), ['2', '1', '3']);
    });

    test('every word must match, exact then prefix then contains', () {
      expect(rankRestaurants(all, 'bengali').map((p) => p.id), ['1', '2']);
      expect(rankRestaurants(all, 'chicken house').map((p) => p.id), ['3']);
      expect(rankRestaurants(all, 'sushi'), isEmpty);
    });

    test('separators and case do not matter', () {
      expect(rankRestaurants(all, ' CHICKEN-house ').map((p) => p.id), ['3']);
    });

    test('directions point at the place', () {
      expect(
        place('1', 'a', 1).directions.queryParameters['destination'],
        '23.4607,91.1809',
      );
    });
  });

  group('overpass parsing', () {
    test('keeps named restaurants inside the radius and tidies cuisine', () {
      final rows = parseRestaurants(
        overpass([
          {
            'type': 'node',
            'id': 1,
            'lat': 23.4607,
            'lon': 91.1809,
            'tags': {
              'name': ' Banyan ',
              'amenity': 'restaurant',
              'cuisine': 'bengali;fast_food',
            },
          },
          {
            'type': 'way',
            'id': 2,
            'center': {'lat': 23.4617, 'lon': 91.1819},
            'tags': {'name': 'Tea', 'amenity': 'cafe'},
          },
          {
            'type': 'node',
            'id': 3,
            'lat': 30.0,
            'lon': 91.0,
            'tags': {'name': 'Far', 'amenity': 'restaurant'},
          },
          {
            'type': 'node',
            'id': 4,
            'lat': 23.46,
            'lon': 91.18,
            'tags': {'amenity': 'restaurant'},
          },
          {
            'type': 'node',
            'id': 5,
            'lat': 23.46,
            'lon': 91.18,
            'tags': {'name': 'Bar', 'amenity': 'bar'},
          },
          {
            'type': 'node',
            'id': -6,
            'lat': 23.46,
            'lon': 91.18,
            'tags': {'name': 'Bad id', 'amenity': 'cafe'},
          },
        ]),
        here,
        3,
      );
      expect(rows.map((r) => r.id), ['node/1', 'way/2']);
      expect(rows.first.name, 'Banyan');
      expect(rows.first.cuisine, 'bengali, fast food');
      expect(rows.last.category, 'Café');
    });

    test('an incomplete response is rejected', () {
      expect(
        () => parseRestaurants(
          utf8.encode('{"elements":[],"remark":"timeout"}'),
          here,
          3,
        ),
        throwsFormatException,
      );
      expect(
        () => parseRestaurants(utf8.encode('[]'), here, 3),
        throwsFormatException,
      );
    });
  });

  group('demo samples', () {
    const seed = '''[{"id":"v1","name":"Banyan","latitude":23.4607,"longitude":91.1809,"menu":[
      {"id":"m1","name":"Dal bowl","portion":"1 bowl","calorie_low":300,"calorie_high":400,"protein_g":12},
      {"id":"m2","name":"Big plate","portion":"1 plate","calorie_low":800,"calorie_high":900}]},
      {"id":"v2","name":"Far","latitude":23.7,"longitude":90.4,"menu":[
      {"id":"m3","name":"Rice","portion":"1","calorie_low":200,"calorie_high":250}]}]''';
    final repo = DemoNearbyRepository(() async => seed);

    test('keeps venues inside the radius and ranks by fit', () async {
      final meals = await repo.sampleMeals(here, 3, 500);
      expect(meals.map((m) => m.id), ['m1', 'm2']);
      expect(meals.first.fit, BudgetFit.fits);
      expect(meals.last.fit, BudgetFit.above);
      expect(meals.first.nutrients[Nutrient.protein], 12);
    });

    test('a bigger radius includes more', () async {
      expect((await repo.sampleMeals(here, 25, null)).length, 2);
      expect(
        (await repo.sampleMeals(
          const GeoPoint(23.7, 90.4),
          3,
          null,
        )).map((m) => m.id),
        ['m3'],
      );
    });

    test('a draft for a nearby meal is marked illustrative', () async {
      final meal = (await repo.sampleMeals(
        here,
        3,
        null,
      )).firstWhere((m) => m.id == 'm1');
      final draft = draftForNearbyMeal(meal, 'd');
      expect(draft.source, MealSource.nearby);
      expect(draft.model, 'demo-fixtures');
      expect(draft.items.single.name, 'Dal bowl');
    });
  });

  group('controller', () {
    late FakeSearch search;
    late FakeLocation location;
    late ProviderContainer container;
    setUp(() {
      search = FakeSearch();
      location = FakeLocation();
      container = ProviderContainer(
        overrides: [
          restaurantSearchProvider.overrideWithValue(search),
          locationServiceProvider.overrideWithValue(location),
        ],
      )..listen(nearbyControllerProvider, (_, _) {});
      addTearDown(container.dispose);
    });
    NearbyController controller() =>
        container.read(nearbyControllerProvider.notifier);
    NearbyState state() => container.read(nearbyControllerProvider);

    test('searching needs a point', () async {
      await controller().search();
      expect(search.searched, isEmpty);
    });

    test('selecting a point clears old results', () async {
      controller().select(here, label: 'Cumilla');
      await controller().search();
      expect(state().restaurants, hasLength(1));
      controller().setRadius(5);
      expect(state().restaurants, isNull);
      expect(state().area, 'Cumilla');
      controller().select(here);
      expect(state().area, isNull);
    });

    test('locating selects the device location and searches', () async {
      await controller().locate();
      expect(state().area, 'Current location');
      expect(search.searched.single.$1, same(here));
      expect(state().restaurants, hasLength(1));
      expect(state().locating, isFalse);
    });

    test('a location failure is shown and nothing is searched', () async {
      location.error = const Failure('Location denied.');
      await controller().locate();
      expect(state().locationError, 'Location denied.');
      expect(search.searched, isEmpty);
    });

    test('a search failure is shown', () async {
      search.error = const Failure('Search is down.');
      controller().select(here);
      await controller().search();
      expect(state().searchError, 'Search is down.');
      expect(state().loading, isFalse);
    });

    test('the query filters without searching again', () async {
      controller().select(here);
      await controller().search();
      controller().setQuery('sushi');
      expect(state().matches, isEmpty);
      controller().setQuery('banyan');
      expect(state().matches, hasLength(1));
      expect(search.searched, hasLength(1));
    });
  });

  group('screen', () {
    Future<(FakeSearch, List<Uri>)> show(
      WidgetTester tester, {
      bool demo = false,
    }) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final search = FakeSearch();
      final opened = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            restaurantSearchProvider.overrideWithValue(search),
            locationServiceProvider.overrideWithValue(FakeLocation()),
            nearbyRepositoryProvider.overrideWithValue(FakeNearby()),
            configProvider.overrideWithValue(
              AppConfig(mode: demo ? 'demo' : 'live'),
            ),
            sessionRepositoryProvider.overrideWithValue(
              FakeSession(demo: demo),
            ),
            overviewRepositoryProvider.overrideWithValue(FakeOverview()),
            urlOpenerProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return true;
            }),
          ],
          child: MaterialApp(
            theme: plateTheme(),
            home: const Scaffold(body: NearbyScreen()),
          ),
        ),
      );
      return (search, opened);
    }

    testWidgets('choose an area, search and open directions', (tester) async {
      final (search, opened) = await show(tester);
      expect(find.text('Choose a search area'), findsOneWidget);
      final button = find.widgetWithText(OutlinedButton, 'Search this area');
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cumilla Town Hall').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search this area'));
      await tester.pumpAndSettle();
      expect(search.searched.single.$2, 3);
      expect(find.text('Banyan'), findsOneWidget);
      expect(find.textContaining('bengali · 500 m'), findsOneWidget);

      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      expect(opened.single.host, 'www.google.com');
    });

    testWidgets('a failed search shows the message with a retry', (
      tester,
    ) async {
      final (search, _) = await show(tester);
      search.error = const Failure('Search is down.');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dhaka Dhanmondi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search this area'));
      await tester.pumpAndSettle();
      expect(find.text('Search is down.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('sample menus are offered only in demo mode', (tester) async {
      await show(tester);
      expect(find.text('Sample menus'), findsNothing);
      await show(tester, demo: true);
      await tester.pumpAndSettle();
      expect(find.text('Sample menus'), findsOneWidget);
    });

    testWidgets('coordinates are validated', (tester) async {
      await show(tester);
      await tester.tap(find.text('Enter coordinates'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Latitude'),
        '95',
      );
      await tester.tap(find.text('Use location'));
      await tester.pumpAndSettle();
      expect(find.text('Enter –85 to 85.'), findsOneWidget);
    });
  });
}
