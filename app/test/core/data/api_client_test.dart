import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:platewise/core/data/api/api_client.dart';
import 'package:platewise/core/domain/domain.dart';

http.Response envelope(Map<String, Object?> body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient client(
  Future<http.Response> Function(http.Request) handler, {
  Future<String> Function()? bearer,
  Duration timeout = const Duration(seconds: 5),
}) => ApiClient(
  endpoint: apiEndpoint('https://abc.supabase.co/'),
  publishableKey: 'pub-key',
  bearer: bearer ?? () async => 'token-1',
  httpClient: MockClient(handler),
  timeout: timeout,
);

Future<Failure> failureOf(Future<Object?> Function() run) async {
  try {
    await run();
  } on Failure catch (failure) {
    return failure;
  }
  fail('expected a Failure');
}

void main() {
  test('the endpoint ignores a trailing slash', () {
    expect(
      apiEndpoint('https://abc.supabase.co/').toString(),
      'https://abc.supabase.co/functions/v1/platewise',
    );
    expect(
      apiEndpoint('https://abc.supabase.co').toString(),
      'https://abc.supabase.co/functions/v1/platewise',
    );
  });

  test('sends a versioned action with the session token', () async {
    late http.Request seen;
    final api = client((request) async {
      seen = request;
      return envelope({
        'version': 1,
        'ok': true,
        'data': {'answer': 42},
      });
    });
    final data = await api.call('analyze_text', {'description': 'rice'});

    expect(data, {'answer': 42});
    expect(seen.method, 'POST');
    expect(
      seen.url.toString(),
      'https://abc.supabase.co/functions/v1/platewise',
    );
    expect(seen.headers['Authorization'], 'Bearer token-1');
    expect(seen.headers['apikey'], 'pub-key');
    expect(seen.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(seen.body), {
      'version': 1,
      'action': 'analyze_text',
      'input': {'description': 'rice'},
    });
  });

  test('an action without input sends an empty object', () async {
    late http.Request seen;
    final api = client((request) async {
      seen = request;
      return envelope({'version': 1, 'ok': true, 'data': <String, Object?>{}});
    });
    await api.call('dashboard');
    expect((jsonDecode(seen.body) as Map)['input'], <String, Object?>{});
  });

  test('a service error becomes a failure with its details', () async {
    final api = client(
      (_) async => envelope({
        'version': 1,
        'ok': false,
        'request_id': 'req-9',
        'error': {
          'code': 'RATE_LIMITED',
          'message': 'Slow down.',
          'retryable': true,
        },
      }, status: 429),
    );
    final failure = await failureOf(() => api.call('analyze_text'));
    expect(failure.message, 'Slow down.');
    expect(failure.code, 'RATE_LIMITED');
    expect(failure.retryable, isTrue);
    expect(failure.requestId, 'req-9');
  });

  test('an error without details still gives a usable failure', () async {
    final api = client((_) async => envelope({'version': 1, 'ok': false}));
    final failure = await failureOf(() => api.call('x'));
    expect(failure.message, 'Please try again.');
    expect(failure.code, 'UNAVAILABLE');
    expect(failure.retryable, isFalse);
    expect(failure.requestId, isNull);
  });

  test('an unreadable body is a retryable failure', () async {
    final api = client((_) async => http.Response('<html>oops</html>', 502));
    final failure = await failureOf(() => api.call('x'));
    expect(failure.message, 'The server returned an unreadable response.');
    expect(failure.retryable, isTrue);
  });

  test('a different protocol version is rejected', () async {
    final api = client(
      (_) async =>
          envelope({'version': 2, 'ok': true, 'data': <String, Object?>{}}),
    );
    final failure = await failureOf(() => api.call('x'));
    expect(failure.message, 'The service returned an unexpected response.');
  });

  test('a body that is not an object is rejected', () async {
    final api = client((_) async => http.Response('[1,2]', 200));
    final failure = await failureOf(() => api.call('x'));
    expect(failure.message, 'The service returned an unexpected response.');
  });

  test('a slow response times out', () async {
    final api = client((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return envelope({'version': 1, 'ok': true, 'data': <String, Object?>{}});
    }, timeout: const Duration(milliseconds: 20));
    final failure = await failureOf(() => api.call('x'));
    expect(failure.code, 'TIMEOUT');
    expect(failure.retryable, isTrue);
  });

  test('a lost connection reads as offline', () async {
    final api = client((_) async => throw http.ClientException('no route'));
    final failure = await failureOf(() => api.call('x'));
    expect(failure.code, 'OFFLINE');
    expect(failure.retryable, isTrue);
  });

  test('a session failure stops the call before any request', () async {
    var requests = 0;
    final api = client(
      (_) async {
        requests++;
        return envelope({
          'version': 1,
          'ok': true,
          'data': <String, Object?>{},
        });
      },
      bearer: () async =>
          throw const Failure('expired', code: 'SESSION_REQUIRED'),
    );
    final failure = await failureOf(() => api.call('x'));
    expect(failure.code, 'SESSION_REQUIRED');
    expect(requests, 0);
  });
}
