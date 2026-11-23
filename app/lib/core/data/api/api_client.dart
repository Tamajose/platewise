import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
      throw _defaultTimeout;
    } on http.ClientException {
      throw _defaultOffline;
    }
  }

  /// Calls an action that carries a file, such as a voice note. Form fields
  /// travel beside the file instead of inside `input`.
  ///
  /// [timedOut] and [offline] replace the default messages, because what to do
  /// next depends on the action.
  Future<Json> callWithFile(
    String action, {
    required Map<String, String> fields,
    required String fileField,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    Failure? timedOut,
    Failure? offline,
  }) async {
    final token = await _bearer();
    final request = http.MultipartRequest('POST', endpoint)
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'apikey': publishableKey,
      })
      ..fields.addAll({'version': '1', 'action': action, ...fields})
      ..files.add(
        http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );
    try {
      final response = await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      return parseResponse(response);
    } on TimeoutException {
      throw timedOut ?? _defaultTimeout;
    } on http.ClientException {
      throw offline ?? _defaultOffline;
    }
  }

  static const _defaultTimeout = Failure(
    'The request took longer than expected. Try again or enter the meal manually.',
    code: 'TIMEOUT',
    retryable: true,
  );
  static const _defaultOffline = Failure(
    'You appear to be offline. Reconnect to sync or edit your draft.',
    code: 'OFFLINE',
    retryable: true,
  );

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
