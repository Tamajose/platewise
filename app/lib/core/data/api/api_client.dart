import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/failure.dart';
import '../json.dart';

typedef BearerSource = Future<String> Function();

/// The Edge Function endpoint for a Supabase project URL.
Uri apiEndpoint(String projectUrl) => Uri.parse(
  '${projectUrl.replaceFirst(RegExp(r'/$'), '')}/functions/v1/platewise',
);

/// Calls the versioned PlateWise API. Every outcome is either a data object
/// or a [Failure], so callers never see transport or protocol errors.
class ApiClient {
  ApiClient({
    required this.endpoint,
    required this.publishableKey,
    required this._bearer,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 24),
  }) : _http = httpClient ?? http.Client();

  final Uri endpoint;
  final String publishableKey;
  final Duration timeout;
  final BearerSource _bearer;
  final http.Client _http;

  Future<Json> call(String action, [Json input = const {}]) async {
    final token = await _bearer();
    try {
      final response = await _http
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'apikey': publishableKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'version': 1, 'action': action, 'input': input}),
          )
          .timeout(timeout);
      return parseResponse(response);
    } on TimeoutException {
      throw const Failure(
        'The request took longer than expected. Try again or enter the meal manually.',
        code: 'TIMEOUT',
        retryable: true,
      );
    } on http.ClientException {
      throw const Failure(
        'You appear to be offline. Reconnect to sync or edit your draft.',
        code: 'OFFLINE',
        retryable: true,
      );
    }
  }

  static Json parseResponse(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const Failure(
        'The server returned an unreadable response.',
        retryable: true,
      );
    }
    if (decoded is! Map || decoded['version'] != 1) {
      throw const Failure(
        'The service returned an unexpected response.',
        retryable: true,
      );
    }
    if (decoded['ok'] != true) {
      final error = decoded['error'] as Map? ?? const {};
      throw Failure(
        error['message'] as String? ?? 'Please try again.',
        code: error['code'] as String? ?? 'UNAVAILABLE',
        retryable: error['retryable'] == true,
        requestId: decoded['request_id'] as String?,
      );
    }
    return Json.from(decoded['data'] as Map);
  }
}
