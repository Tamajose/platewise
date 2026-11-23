import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/config/app_config_provider.dart';
import '../core/data/api/api_client.dart';
import '../core/data/auth/auth_session.dart';
import '../core/data/core_providers.dart';
import '../core/data/demo/demo_store.dart';
import '../core/data/overview/demo_overview_repository.dart';
import '../core/data/overview/live_overview_repository.dart';
import '../core/data/session/demo_session_repository.dart';
import '../core/data/session/live_session_repository.dart';

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
  ];
}
