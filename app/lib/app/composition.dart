import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/config/app_config_provider.dart';
import '../core/data/api/api_client.dart';
import '../core/data/auth/auth_session.dart';
import '../core/data/core_providers.dart';
import '../core/data/demo/demo_store.dart';
import '../core/data/media/demo_media_storage.dart';
import '../core/data/profile/profile_repositories.dart';
import '../core/data/media/image_picker_photo_picker.dart';
import '../core/data/media/live_media_storage.dart';
import '../core/data/overview/demo_overview_repository.dart';
import '../core/data/overview/live_overview_repository.dart';
import '../core/data/session/demo_session_repository.dart';
import '../core/data/session/live_session_repository.dart';
import '../features/auth/data/account_providers.dart';
import '../features/auth/data/account_repositories.dart';
import '../features/auth/data/auth_backend.dart';
import '../features/comparison/data/comparison_providers.dart';
import '../features/comparison/data/demo_comparison_repository.dart';
import '../features/comparison/data/live_comparison_repository.dart';
import '../features/meal_logging/data/demo_meal_log_repository.dart';
import '../features/nearby/data/geolocator_location_service.dart';
import '../features/onboarding/data/onboarding_providers.dart';
import '../features/onboarding/data/onboarding_repositories.dart';
import '../features/settings/data/settings_providers.dart';
import '../features/settings/data/settings_repositories.dart';
import '../features/today/data/today_providers.dart';
import '../features/water/data/water_providers.dart';
import '../features/weekly/data/weekly_providers.dart';
import '../features/weekly/data/weekly_repositories.dart';
import '../features/water/data/water_repositories.dart';
import '../features/today/data/today_repositories.dart';
import '../features/nearby/data/nearby_providers.dart';
import '../features/nearby/data/nearby_repositories.dart';
import '../features/nearby/data/overpass_restaurant_search.dart';
import '../features/meal_logging/data/demo_speech_transcriber.dart';
import '../features/meal_logging/data/live_meal_log_repository.dart';
import '../features/meal_logging/data/live_speech_transcriber.dart';
import '../features/meal_logging/data/meal_log_providers.dart';
import '../features/meal_logging/data/record_voice_recorder.dart';
import '../features/meal_logging/domain/voice.dart';

/// The app cannot start. [message] is safe to show to a person.
class StartupException implements Exception {
  const StartupException(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef SupabaseConnector = Future<SupabaseClient> Function(AppConfig config);

Future<SupabaseClient> connectSupabase(AppConfig config) async {
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
  );
  return Supabase.instance.client;
}

/// Chooses demo or live data and returns the provider overrides that wire the
/// chosen implementations into the app. Later migration steps add each
/// feature's repository here.
///
/// Throws [StartupException] when a live build is not configured or cannot
/// reach Supabase.
Future<List<Override>> composeOverrides(
  AppConfig config, {
  SharedPreferencesAsync? preferences,
  SupabaseConnector connect = connectSupabase,
}) async {
  if (config.demo) {
    final store = DemoStore(preferences ?? SharedPreferencesAsync());
    return [
      configProvider.overrideWithValue(config),
      sessionRepositoryProvider.overrideWithValue(DemoSessionRepository(store)),
      overviewRepositoryProvider.overrideWithValue(
        DemoOverviewRepository(store),
      ),
      mediaStorageProvider.overrideWithValue(const DemoMediaStorage()),
      photoPickerProvider.overrideWithValue(ImagePickerPhotoPicker()),
      mealLogRepositoryProvider.overrideWithValue(DemoMealLogRepository(store)),
      speechTranscriberProvider.overrideWithValue(
        const DemoSpeechTranscriber(),
      ),
      voiceRecorderProvider.overrideWith(_deviceRecorder),
      comparisonRepositoryProvider.overrideWithValue(
        DemoComparisonRepository(),
      ),
      accountRepositoryProvider.overrideWithValue(
        const DemoAccountRepository(),
      ),
      nearbyRepositoryProvider.overrideWithValue(
        DemoNearbyRepository(
          () => rootBundle.loadString('assets/data/seeded_menus.json'),
        ),
      ),
      todayRepositoryProvider.overrideWithValue(DemoTodayRepository(store)),
      waterRepositoryProvider.overrideWithValue(DemoWaterRepository(store)),
      weeklyRepositoryProvider.overrideWithValue(DemoWeeklyRepository(store)),
      profileRepositoryProvider.overrideWithValue(DemoProfileRepository(store)),
      settingsRepositoryProvider.overrideWithValue(
        DemoSettingsRepository(store),
      ),
      onboardingRepositoryProvider.overrideWithValue(
        DemoOnboardingRepository(store),
      ),
      ..._nearbyServices(),
    ];
  }
  if (!config.canConnect) {
    throw const StartupException(
      'This live build needs a Supabase URL and publishable key. Check the build configuration.',
    );
  }
  final SupabaseClient client;
  try {
    client = await connect(config);
  } on Object {
    throw const StartupException(
      'A secure session could not be initialized. Check the connection and reopen PlateWise.',
    );
  }
  final auth = SupabaseAuthSession(client);
  final api = ApiClient(
    endpoint: apiEndpoint(config.url),
    publishableKey: config.publishableKey,
    bearer: auth.bearer,
  );
  return [
    configProvider.overrideWithValue(config),
    sessionRepositoryProvider.overrideWithValue(
      LiveSessionRepository(auth, api),
    ),
    overviewRepositoryProvider.overrideWithValue(LiveOverviewRepository(api)),
    mediaStorageProvider.overrideWithValue(
      LiveMediaStorage(
        auth: auth,
        api: api,
        upload: (path, bytes) => client.storage
            .from('meal-media')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            ),
      ),
    ),
    photoPickerProvider.overrideWithValue(ImagePickerPhotoPicker()),
    mealLogRepositoryProvider.overrideWithValue(LiveMealLogRepository(api)),
    speechTranscriberProvider.overrideWithValue(LiveSpeechTranscriber(api)),
    voiceRecorderProvider.overrideWith(_deviceRecorder),
    comparisonRepositoryProvider.overrideWithValue(
      LiveComparisonRepository(api),
    ),
    nearbyRepositoryProvider.overrideWithValue(LiveNearbyRepository(api)),
    accountRepositoryProvider.overrideWithValue(
      LiveAccountRepository(SupabaseAuthBackend(auth)),
    ),
    userChangesProvider.overrideWith(
      (ref) => client.auth.onAuthStateChange.map(
        (change) => change.session?.user.id,
      ),
    ),
    todayRepositoryProvider.overrideWithValue(LiveTodayRepository(api)),
    waterRepositoryProvider.overrideWithValue(LiveWaterRepository(api)),
    weeklyRepositoryProvider.overrideWithValue(LiveWeeklyRepository(api)),
    profileRepositoryProvider.overrideWithValue(LiveProfileRepository(api)),
    settingsRepositoryProvider.overrideWithValue(
      LiveSettingsRepository(
        api,
        signOutLocally: () => client.auth.signOut(scope: SignOutScope.local),
      ),
    ),
    onboardingRepositoryProvider.overrideWithValue(
      const LiveOnboardingRepository(),
    ),
    ..._nearbyServices(),
  ];
}

/// One recorder per voice session, released when voice entry closes.
VoiceRecorder _deviceRecorder(Ref ref) {
  final recorder = RecordVoiceRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
}

/// Restaurant search and device location are the same in demo and live mode.
List<Override> _nearbyServices() => [
  restaurantSearchProvider.overrideWithValue(
    OverpassRestaurantSearch(http.Client()),
  ),
  locationServiceProvider.overrideWithValue(const GeolocatorLocationService()),
];
