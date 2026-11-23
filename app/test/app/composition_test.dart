import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/app/app.dart';
import 'package:platewise/app/composition.dart';
import 'package:platewise/app/startup_error_app.dart';
import 'package:platewise/core/config/app_config.dart';
import 'package:platewise/core/config/app_config_provider.dart';
import 'package:platewise/core/data/core_providers.dart';
import 'package:platewise/core/presentation/session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const liveConfig = AppConfig(
  mode: 'live',
  url: 'https://abc.supabase.co',
  publishableKey: 'pub-key',
);

SupabaseClient offlineClient() => SupabaseClient(
  'https://abc.supabase.co',
  'pub-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('demo mode', () {
    test('wires local sample data with no capabilities', () async {
      final overrides = await composeOverrides(
        const AppConfig(mode: 'demo'),
        preferences: SharedPreferencesAsync(),
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(configProvider).demo, isTrue);
      expect(container.read(sessionRepositoryProvider).isDemo, isTrue);
      final overview = await container.read(overviewProvider.future);
      expect(overview.profile, isNull);
      expect(overview.meals, isEmpty);
      expect(await container.read(capabilitiesProvider.future), (
        liveAi: false,
        banglaText: false,
        banglaSpeech: false,
      ));
    });

    testWidgets('the app builds with the composed overrides', (tester) async {
      final overrides = await composeOverrides(
        const AppConfig(mode: 'demo'),
        preferences: SharedPreferencesAsync(),
      );
      await tester.pumpWidget(
        ProviderScope(overrides: overrides, child: const PlateWiseApp()),
      );
      expect(find.text('PlateWise'), findsOneWidget);
    });
  });

  group('live mode', () {
    test('refuses to start without a project URL and key', () async {
      await expectLater(
        composeOverrides(const AppConfig(mode: 'live')),
        throwsA(
          isA<StartupException>().having(
            (e) => e.message,
            'message',
            contains('Supabase URL and publishable key'),
          ),
        ),
      );
    });

    test('refuses an insecure project URL', () async {
      await expectLater(
        composeOverrides(
          const AppConfig(
            mode: 'live',
            url: 'http://abc.supabase.co',
            publishableKey: 'k',
          ),
        ),
        throwsA(isA<StartupException>()),
      );
    });

    test('reports a connection failure without leaking details', () async {
      await expectLater(
        composeOverrides(
          liveConfig,
          connect: (_) async => throw StateError('socket secret'),
        ),
        throwsA(
          isA<StartupException>().having(
            (e) => e.message,
            'message',
            allOf(contains('secure session'), isNot(contains('secret'))),
          ),
        ),
      );
    });

    test('wires the backend implementations', () async {
      final overrides = await composeOverrides(
        liveConfig,
        connect: (_) async => offlineClient(),
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(configProvider).demo, isFalse);
      expect(container.read(sessionRepositoryProvider).isDemo, isFalse);
      expect(overrides, hasLength(3));
    });
  });

  testWidgets('the startup error screen shows the message', (tester) async {
    await tester.pumpWidget(const StartupErrorApp('Cannot start.'));
    expect(find.text('Cannot start.'), findsOneWidget);
    expect(find.text('PlateWise'), findsOneWidget);
  });
}
