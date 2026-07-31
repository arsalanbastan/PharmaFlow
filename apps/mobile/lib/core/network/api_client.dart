import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_constants.dart';
import 'models/health_response.dart';

class ApiClient {
  ApiClient({AppConfig? appConfig, http.Client? httpClient, Duration? timeout})
    : _httpClient = httpClient ?? http.Client(),
      _appConfig = appConfig ?? AppConfig.defaults(),
      _timeoutOverride = timeout;

  final http.Client _httpClient;
  final AppConfig _appConfig;
  final Duration? _timeoutOverride;

  Duration get _timeout {
    final override = _timeoutOverride;
    if (override != null) {
      return override;
    }

    final milliseconds = _appConfig.connectTimeout + _appConfig.receiveTimeout;

    return Duration(milliseconds: milliseconds);
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(endpoint, queryParameters: queryParameters);

    try {
      final response = await _httpClient
          .get(
            uri,
            headers: {
              HttpHeaders.acceptHeader: 'application/json',
              ...?headers,
            },
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on TimeoutException catch (error) {
      throw ApiTimeoutException(
        'Request timed out after ${_timeout.inSeconds} seconds.',
        error,
      );
    } on SocketException catch (error) {
      throw ApiNetworkException(
        'No network connection or server is unreachable.',
        error,
      );
    } on FormatException catch (error) {
      throw ApiDecodingException('Response was not valid JSON.', error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiUnknownException(
        'Unexpected error while sending request.',
        error,
      );
    }
  }

  Future<List<dynamic>> verifyCompaniesListEndpoint() async {
    final payload = await get(ApiConstants.companiesEndpoint);

    if (payload is List<dynamic>) {
      return payload;
    }

    throw ApiDecodingException(
      'Expected a JSON list from GET ${ApiConstants.companiesEndpoint}.',
    );
  }

  Future<HealthResponse> checkHealth() async {
    final stopwatch = Stopwatch()..start();
    final payload = await get(ApiConstants.healthEndpoint);
    stopwatch.stop();

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from GET /health.',
      );
    }

    return HealthResponse.fromJson(
      payload,
    ).copyWith(responseDuration: stopwatch.elapsed);
  }

  Uri _buildUri(String endpoint, {Map<String, String>? queryParameters}) {
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;

    final baseUri = Uri.parse('${_appConfig.baseUrl}/');

    return baseUri
        .resolve(normalizedEndpoint)
        .replace(queryParameters: queryParameters);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response.body),
        body: response.body,
      );
    }

    if (response.body.isEmpty) {
      throw const ApiDecodingException('Response body was empty.');
    }

    return jsonDecode(response.body);
  }

  String _extractErrorMessage(String body) {
    if (body.isEmpty) {
      return 'Server returned an error response.';
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      // Keep a fallback message when body is not JSON.
    }

    return 'Server returned an error response.';
  }
}

abstract class ApiException implements Exception {
  const ApiException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ApiException: $message';
}

class ApiHttpException extends ApiException {
  const ApiHttpException({
    required this.statusCode,
    required String message,
    this.body,
    Object? cause,
  }) : super(message, cause);

  final int statusCode;
  final String? body;

  @override
  String toString() {
    return 'ApiHttpException(statusCode: $statusCode, message: $message)';
  }
}

class ApiNetworkException extends ApiException {
  const ApiNetworkException(super.message, [super.cause]);
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException(super.message, [super.cause]);
}

class ApiDecodingException extends ApiException {
  const ApiDecodingException(super.message, [super.cause]);
}

class ApiUnknownException extends ApiException {
  const ApiUnknownException(super.message, [super.cause]);
}
