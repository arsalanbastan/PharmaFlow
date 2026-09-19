import 'dart:convert';

import 'package:http/http.dart' as http;

import 'staff_auth_session.dart';
import 'staff_auth_token_storage.dart';
import 'staff_auth_user.dart';

class StaffAuthApiException implements Exception {
  const StaffAuthApiException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class StaffAuthApiService {
  static const String _baseUrl = String.fromEnvironment(
    'PHARMAFLOW_API_BASE_URL',
    defaultValue: 'https://naughty-haslett-zvtszb2yr.liara.run/api/v1',
  );

  StaffAuthApiService({http.Client? httpClient, StaffAuthTokenStorage? storage})
    : _httpClient = httpClient ?? http.Client(),
      _storage = storage ?? StaffAuthTokenStorage();

  final http.Client _httpClient;
  final StaffAuthTokenStorage _storage;

  Future<StaffAuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _requestJson(
      method: 'POST',
      path: '/auth/login',
      body: {'username': username.trim(), 'password': password},
    );
    final token = (response['token'] as String?)?.trim();
    final userJson = response['user'];

    if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
      throw const FormatException('Login response is incomplete.');
    }

    final user = StaffAuthUser.fromJson(userJson);

    if (!user.isStaff) {
      throw const StaffAuthApiException(
        statusCode: 403,
        message: 'این حساب برای برنامه کارکنان مجاز نیست.',
      );
    }

    final expiresRaw = (response['expiresAt'] as String?)?.trim();
    final session = StaffAuthSession(
      token: token,
      user: user,
      expiresAt: expiresRaw == null || expiresRaw.isEmpty
          ? null
          : DateTime.tryParse(expiresRaw),
    );

    await _storage.save(session);
    return session;
  }

  Future<StaffAuthUser> me() async {
    final token = await _storage.readToken();

    if (token == null) {
      throw const StaffAuthApiException(
        statusCode: 401,
        message: 'نشست کاربری موجود نیست.',
      );
    }

    final response = await _requestJson(
      method: 'GET',
      path: '/auth/me',
      bearerToken: token,
    );
    final userJson = response['user'];

    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Current user response is incomplete.');
    }

    return StaffAuthUser.fromJson(userJson);
  }

  Future<void> logout() async {
    final token = await _storage.readToken();

    try {
      if (token != null) {
        await _requestJson(
          method: 'POST',
          path: '/auth/logout',
          bearerToken: token,
          body: const <String, dynamic>{},
        );
      }
    } finally {
      await _storage.clear();
    }
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};
    final normalizedToken = bearerToken?.trim();

    if (normalizedToken != null && normalizedToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $normalizedToken';
    }

    http.Response response;

    if (method == 'GET') {
      response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    } else {
      headers['Content-Type'] = 'application/json; charset=utf-8';
      response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
          .timeout(const Duration(seconds: 20));
    }

    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StaffAuthApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response.statusCode, responseBody),
      );
    }

    if (responseBody.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Server response is not a JSON object.');
    }

    return decoded;
  }

  String _errorMessage(int statusCode, String responseBody) {
    var message = 'Server returned HTTP $statusCode.';

    if (responseBody.isEmpty) {
      return message;
    }

    try {
      final decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        final rawMessage = decoded['message'];

        if (rawMessage is String && rawMessage.trim().isNotEmpty) {
          return rawMessage;
        }

        if (rawMessage is List && rawMessage.isNotEmpty) {
          return rawMessage.join('\n');
        }
      }
    } catch (_) {
      message = responseBody;
    }

    return message;
  }

  void close() {
    _httpClient.close();
  }
}
