import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as im;
import 'package:platewise/core/data/api/api_client.dart';
import 'package:platewise/core/data/auth/auth_session.dart';
import 'package:platewise/core/data/media/demo_media_storage.dart';
import 'package:platewise/core/data/media/live_media_storage.dart';
import 'package:platewise/core/data/media/photo_processing.dart';
import 'package:platewise/core/domain/domain.dart';

class _Auth implements AuthSession {
  _Auth(this.userId);
  @override
  final String? userId;
  @override
  Future<void> ensureSession() async {}
  @override
  Future<String> bearer() async => 't';
}

({LiveMediaStorage storage, List<String> actions, List<String> uploaded}) rig({
  String? user = 'u1',
  Object? uploadError,
  Duration? slow,
  Duration timeout = const Duration(seconds: 5),
}) {
  final actions = <String>[];
  final uploaded = <String>[];
  final api = ApiClient(
    endpoint: apiEndpoint('https://abc.supabase.co'),
    publishableKey: 'k',
    bearer: () async => 't',
    httpClient: MockClient((request) async {
      actions.add((jsonDecode(request.body) as Map)['action'] as String);
      return http.Response(
        jsonEncode({'version': 1, 'ok': true, 'data': <String, Object?>{}}),
        200,
      );
    }),
  );
  final storage = LiveMediaStorage(
    auth: _Auth(user),
    api: api,
    generateId: () => 'photo-1',
    timeout: timeout,
    upload: (path, bytes) async {
      if (slow != null) await Future<void>.delayed(slow);
      if (uploadError != null) throw uploadError;
      uploaded.add(path);
    },
  );
  return (storage: storage, actions: actions, uploaded: uploaded);
}

void main() {
  group('live media storage', () {
    test('stores a photo in the person\'s own folder', () async {
      final r = rig();
      final path = await r.storage.upload(Uint8List(3));
      expect(path, 'u1/photo-1.jpg');
      expect(r.uploaded, ['u1/photo-1.jpg']);
    });

    test('needs a session', () async {
      final r = rig(user: null);
      await expectLater(
        r.storage.upload(Uint8List(3)),
        throwsA(isA<Failure>()),
      );
      expect(r.uploaded, isEmpty);
    });

    test('a failed upload becomes a retryable failure', () async {
      final r = rig(uploadError: StateError('secret path'));
      await expectLater(
        r.storage.upload(Uint8List(3)),
        throwsA(
          isA<Failure>()
              .having((f) => f.retryable, 'retryable', isTrue)
              .having((f) => f.message, 'message', isNot(contains('secret'))),
        ),
      );
    });

    test('a slow upload times out', () async {
      final r = rig(
        slow: const Duration(milliseconds: 200),
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        r.storage.upload(Uint8List(3)),
        throwsA(isA<Failure>()),
      );
    });

    test('discarding asks the service, and only for a real path', () async {
      final r = rig();
      await r.storage.discard(null);
      expect(r.actions, isEmpty);
      await r.storage.discard('u1/photo-1.jpg');
      await r.storage.retryCleanup();
      expect(r.actions, ['discard_photo', 'retry_media_cleanup']);
    });
  });

  test('demo mode stores nothing', () async {
    const storage = DemoMediaStorage();
    expect(await storage.upload(Uint8List(3)), isNull);
    await storage.discard('x');
    await storage.retryCleanup();
  });

  group('photo processing', () {
    Uint8List png(int width, int height) => Uint8List.fromList(
      im.encodePng(im.Image(width: width, height: height, numChannels: 4)),
    );

    test('re-encodes as JPEG', () {
      final out = preparePhoto(png(40, 30))!;
      expect(out.sublist(0, 2), [0xFF, 0xD8]);
      final decoded = im.decodeJpg(out)!;
      expect((decoded.width, decoded.height), (40, 30));
    });

    test('shrinks the long side to the limit and keeps the aspect', () {
      final wide = im.decodeJpg(preparePhoto(png(3000, 1500))!)!;
      expect((wide.width, wide.height), (maxPhotoSide, 750));
      final tall = im.decodeJpg(preparePhoto(png(1000, 2000))!)!;
      expect((tall.width, tall.height), (750, maxPhotoSide));
    });

    test('leaves a small photo at its size', () {
      final decoded = im.decodeJpg(preparePhoto(png(800, 600))!)!;
      expect((decoded.width, decoded.height), (800, 600));
    });

    test('something that is not an image gives null', () {
      expect(preparePhoto(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });
}
