import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:platewise/core/data/api/api_client.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/meal_logging/data/demo_meal_log_repository.dart';
import 'package:platewise/features/meal_logging/data/demo_speech_transcriber.dart';
import 'package:platewise/features/meal_logging/data/live_meal_log_repository.dart';
import 'package:platewise/features/meal_logging/data/live_speech_transcriber.dart';
import 'package:platewise/features/meal_logging/domain/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../fakes.dart';

Map<String, Object?> estimate() => {
  'items': [
    {
      'name': 'Steamed rice',
      'quantity': 1,
      'unit': 'cup',
      'calorie_low': 175,
      'calorie_high': 225,
      'protein_g': 4,
    },
  ],
  'confidence': 'medium',
  'assumptions': ['One cup.'],
  'model': 'gpt-test',
};

/// An API client whose service answers every action with [data], recording the
/// requests it received.
({ApiClient api, List<http.BaseRequest> requests}) service(
  Map<String, Object?> data,
) {
  final requests = <http.BaseRequest>[];
  final client = MockClient.streaming((request, body) async {
    requests.add(request);
    final text = await http.ByteStream(body).bytesToString();
    requests.add(http.Request(request.method, request.url)..body = text);
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(jsonEncode({'version': 1, 'ok': true, 'data': data})),
      ),
      200,
    );
  });
  final api = ApiClient(
    endpoint: apiEndpoint('https://abc.supabase.co'),
    publishableKey: 'k',
    bearer: () async => 't',
    httpClient: client,
  );
  return (api: api, requests: requests);
}

Map<String, Object?> sentBody(List<http.BaseRequest> requests) =>
    jsonDecode((requests.last as http.Request).body) as Map<String, Object?>;

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('live meal log', () {
    test('a photo estimate carries the photo and a fresh id', () async {
      final s = service(estimate());
      final repo = LiveMealLogRepository(s.api, generateId: () => 'draft-1');
      final draft = await repo.analyzePhoto('u/p.jpg');
      expect(sentBody(s.requests)['action'], 'analyze_photo');
      expect(sentBody(s.requests)['input'], {'image_storage_path': 'u/p.jpg'});
      expect(draft.id, 'draft-1');
      expect(draft.source, MealSource.photo);
      expect(draft.imagePath, 'u/p.jpg');
      expect(draft.confidence, Confidence.medium);
      expect(draft.items.single.nutrients[Nutrient.protein], 4);
    });

    test('a photo estimate without a photo fails before any request', () async {
      final s = service(estimate());
      final repo = LiveMealLogRepository(s.api);
      await expectLater(repo.analyzePhoto(null), throwsA(isA<Failure>()));
      expect(s.requests, isEmpty);
    });

    test('a text estimate sends the description and language', () async {
      final s = service(estimate());
      final draft = await LiveMealLogRepository(
        s.api,
        generateId: () => 'draft-2',
      ).analyzeText('rice', 'bn', source: MealSource.voice);
      expect(sentBody(s.requests)['input'], {
        'description': 'rice',
        'language': 'bn',
      });
      expect(draft.source, MealSource.voice);
      expect(draft.id, 'draft-2');
    });

    Map<String, Object?> savedRow() => {
      ...estimate(),
      'id': 'm1',
      'source': 'text',
      'consumed_at': '2026-11-22T06:00:00+00:00',
      'updated_at': '2026-11-22T06:00:01+00:00',
      'representative_calories': 200,
    };

    test('a new meal is confirmed', () async {
      final s = service(savedRow());
      final saved = await LiveMealLogRepository(s.api).save(draftOf([rice]));
      expect(sentBody(s.requests)['action'], 'confirm_meal');
      expect(saved.id, 'm1');
      expect(saved.updatedAt, '2026-11-22T06:00:01+00:00');
    });

    test('a saved meal is edited with its revision', () async {
      final s = service(savedRow());
      final edited = const MealDraft(
        id: 'm1',
        source: MealSource.text,
        items: [rice],
        expectedUpdatedAt: 'rev-1',
      );
      await LiveMealLogRepository(s.api).save(edited);
      final body = sentBody(s.requests);
      expect(body['action'], 'edit_meal');
      expect((body['input']! as Map)['expected_updated_at'], 'rev-1');
    });

    test('a meal photo link comes from the service', () async {
      final s = service({'signed_url': 'https://x/y.jpg'});
      final url = await LiveMealLogRepository(s.api).imageUrl('m1');
      expect(url, 'https://x/y.jpg');
      expect(sentBody(s.requests)['input'], {'id': 'm1'});
    });

    test('offers no sample draft', () {
      expect(LiveMealLogRepository(service({}).api).sampleDraft(), isNull);
    });
  });

  group('live transcription', () {
    test('sends the audio as a file with the language beside it', () async {
      final requests = <http.BaseRequest>[];
      String? body;
      final client = MockClient.streaming((request, stream) async {
        requests.add(request);
        body = utf8.decode(
          await stream.expand((c) => c).toList(),
          allowMalformed: true,
        );
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'version': 1,
                'ok': true,
                'data': {'transcript': 'one cup of rice'},
              }),
            ),
          ),
          200,
        );
      });
      final api = ApiClient(
        endpoint: apiEndpoint('https://abc.supabase.co'),
        publishableKey: 'k',
        bearer: () async => 't',
        httpClient: client,
      );
      final text = await LiveSpeechTranscriber(api).transcribe(
        VoiceRecording(
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'meal.webm',
          mime: 'audio/webm',
        ),
        'bn',
      );
      expect(text, 'one cup of rice');
      expect(requests.single.headers['Authorization'], 'Bearer t');
      expect(body, contains('name="action"'));
      expect(body, contains('transcribe_voice'));
      expect(body, contains('name="language"'));
      expect(body, contains('filename="meal.webm"'));
      expect(body, contains('audio/webm'));
    });

    test('a slow service gives the transcription message', () async {
      final api = ApiClient(
        endpoint: apiEndpoint('https://abc.supabase.co'),
        publishableKey: 'k',
        bearer: () async => 't',
        timeout: const Duration(milliseconds: 10),
        httpClient: MockClient.streaming((_, _) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.StreamedResponse(const Stream.empty(), 200);
        }),
      );
      await expectLater(
        LiveSpeechTranscriber(api).transcribe(
          VoiceRecording(
            bytes: Uint8List(1),
            filename: 'a.m4a',
            mime: 'audio/mp4',
          ),
          'en',
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Transcription took too long. Try again or type the meal.',
          ),
        ),
      );
    });

    test('a lost connection gives the speech service message', () async {
      final api = ApiClient(
        endpoint: apiEndpoint('https://abc.supabase.co'),
        publishableKey: 'k',
        bearer: () async => 't',
        httpClient: MockClient.streaming(
          (_, _) async => throw http.ClientException('down'),
        ),
      );
      await expectLater(
        LiveSpeechTranscriber(api).transcribe(
          VoiceRecording(
            bytes: Uint8List(1),
            filename: 'a.m4a',
            mime: 'audio/mp4',
          ),
          'en',
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Speech service is offline. Type the meal to continue.',
          ),
        ),
      );
    });

    test('demo mode has no speech service', () async {
      await expectLater(
        const DemoSpeechTranscriber().transcribe(
          VoiceRecording(bytes: Uint8List(1), filename: 'a', mime: 'audio/mp4'),
          'en',
        ),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('demo meal log', () {
    late DemoStore store;
    late DemoMealLogRepository repo;
    var counter = 0;

    setUp(() {
      store = DemoStore(SharedPreferencesAsync());
      counter = 0;
      repo = DemoMealLogRepository(store, generateId: () => 'id-${++counter}');
    });

    test('estimates from the catalog', () async {
      final draft = await repo.analyzeText('rice and dal', 'en');
      expect(draft.items.map((i) => i.name), ['Steamed rice', 'Masoor dal']);
      expect(draft.model, 'demo-fixtures');
      expect(draft.confidence, Confidence.low);
    });

    test('keeps the capture source', () async {
      final draft = await repo.analyzeText(
        'biryani',
        'en',
        source: MealSource.voice,
      );
      expect(draft.source, MealSource.voice);
    });

    test('an unknown dish and Bangla are explained', () async {
      await expectLater(
        repo.analyzeText('sushi', 'en'),
        throwsA(isA<Failure>().having((f) => f.code, 'code', 'DEMO_NO_MATCH')),
      );
      await expectLater(
        repo.analyzeText('rice', 'bn'),
        throwsA(
          isA<Failure>().having((f) => f.code, 'code', 'LANGUAGE_UNAVAILABLE'),
        ),
      );
    });

    test('photo estimates need a live backend', () async {
      await expectLater(
        repo.analyzePhoto('x'),
        throwsA(isA<Failure>().having((f) => f.code, 'code', 'DEMO_ONLY')),
      );
    });

    test('offers a sample draft with a fresh id', () {
      final sample = repo.sampleDraft()!;
      expect(sample.items, hasLength(2));
      expect(sample.id, 'id-1');
      expect(repo.sampleDraft()!.id, 'id-2');
    });

    test('a saved meal appears in the overview', () async {
      final draft = await repo.analyzeText('rice', 'en');
      final saved = await repo.save(draft);
      final overview = await store.read();
      expect(overview.meals.single.id, saved.id);
      expect(saved.representative, draft.range.midpoint);
    });

    test('saving the same new draft twice keeps one meal', () async {
      final draft = await repo.analyzeText('rice', 'en');
      final first = await repo.save(draft);
      final second = await repo.save(draft);
      expect((await store.read()).meals, hasLength(1));
      expect(second.updatedAt, first.updatedAt);
    });

    test('an edit replaces the meal and keeps its time', () async {
      final first = await repo.save(await repo.analyzeText('rice', 'en'));
      final edited = first.editable.revise([rice, rice]);
      final second = await repo.save(edited);
      final meals = (await store.read()).meals;
      expect(meals, hasLength(1));
      expect(meals.single.draft.items, hasLength(2));
      expect(second.at, first.at);
    });

    test('an edit of a changed or missing meal fails', () async {
      final first = await repo.save(await repo.analyzeText('rice', 'en'));
      final stale = MealDraft(
        id: first.id,
        source: first.draft.source,
        items: first.draft.items,
        expectedUpdatedAt: 'older',
      );
      await expectLater(repo.save(stale), throwsA(isA<Failure>()));
      final missing = MealDraft(
        id: 'gone',
        source: MealSource.manual,
        items: const [rice],
        expectedUpdatedAt: 'x',
      );
      await expectLater(repo.save(missing), throwsA(isA<Failure>()));
      expect((await store.read()).meals, hasLength(1));
    });

    test('has no photo links', () async {
      expect(await repo.imageUrl('m1'), isNull);
    });
  });
}
