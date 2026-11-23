import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:platewise/core/data/api/api_client.dart';
import 'package:platewise/core/data/auth/auth_session.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/core/data/overview/demo_overview_repository.dart';
import 'package:platewise/core/data/overview/live_overview_repository.dart';
import 'package:platewise/core/data/session/demo_session_repository.dart';
import 'package:platewise/core/data/session/live_session_repository.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class FakeAuth implements AuthSession {
  int sessions = 0;
  Completer<void>? gate;
  Object? failure;

  @override
  String? get userId => 'u1';

  @override
  Future<void> ensureSession() async {
    sessions++;
    await gate?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<String> bearer() async => 'token';
}

ApiClient apiReturning(Map<String, Object?> data, {List<String>? actions}) =>
    ApiClient(
      endpoint: apiEndpoint('https://abc.supabase.co'),
      publishableKey: 'k',
      bearer: () async => 't',
      httpClient: MockClient((request) async {
        actions?.add((jsonDecode(request.body) as Map)['action'] as String);
        return http.Response(
          jsonEncode({'version': 1, 'ok': true, 'data': data}),
          200,
        );
      }),
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('live session', () {
    test('reports that it is not a demo', () {
      expect(
        LiveSessionRepository(FakeAuth(), apiReturning({})).isDemo,
        isFalse,
      );
    });

    test('concurrent bootstraps share one sign-in', () async {
      final auth = FakeAuth()..gate = Completer<void>();
      final repo = LiveSessionRepository(auth, apiReturning({}));
      final first = repo.bootstrap();
      final second = repo.bootstrap();
      auth.gate!.complete();
      await Future.wait([first, second]);
      expect(auth.sessions, 1);
    });

    test('a later bootstrap checks the session again', () async {
      final auth = FakeAuth();
      final repo = LiveSessionRepository(auth, apiReturning({}));
      await repo.bootstrap();
      await repo.bootstrap();
      expect(auth.sessions, 2);
    });

    test('a failed bootstrap can be retried', () async {
      final auth = FakeAuth()..failure = const Failure('offline');
      final repo = LiveSessionRepository(auth, apiReturning({}));
      await expectLater(repo.bootstrap(), throwsA(isA<Failure>()));
      auth.failure = null;
      await repo.bootstrap();
      expect(auth.sessions, 2);
    });

    test('capabilities come from the service', () async {
      final actions = <String>[];
      final repo = LiveSessionRepository(
        FakeAuth(),
        apiReturning({
          'live_ai': true,
          'bangla_text': false,
          'bangla_speech': true,
        }, actions: actions),
      );
      expect(await repo.capabilities(), (
        liveAi: true,
        banglaText: false,
        banglaSpeech: true,
      ));
      expect(actions, ['capabilities']);
    });

    test('missing flags count as off', () async {
      final repo = LiveSessionRepository(FakeAuth(), apiReturning({}));
      expect(await repo.capabilities(), (
        liveAi: false,
        banglaText: false,
        banglaSpeech: false,
      ));
    });
  });

  group('demo session', () {
    test('is a demo with every capability off', () async {
      final repo = DemoSessionRepository(DemoStore(SharedPreferencesAsync()));
      expect(repo.isDemo, isTrue);
      await repo.bootstrap();
      expect(await repo.capabilities(), (
        liveAi: false,
        banglaText: false,
        banglaSpeech: false,
      ));
    });
  });

  group('overview', () {
    test('live reads the dashboard action', () async {
      final actions = <String>[];
      final repo = LiveOverviewRepository(
        apiReturning({
          'profile': null,
          'meals': <Object?>[],
          'pending_asset_count': 3,
        }, actions: actions),
      );
      final overview = await repo.overview();
      expect(actions, ['dashboard']);
      expect(overview.pendingAssets, 3);
    });

    test('demo reads what the demo store holds', () async {
      final store = DemoStore(SharedPreferencesAsync());
      await store.update(
        (_) => const Overview(
          profile: Profile(height: 170, weight: 70, target: null),
        ),
      );
      final overview = await DemoOverviewRepository(store).overview();
      expect(overview.profile!.weight, 70);
    });
  });
}
