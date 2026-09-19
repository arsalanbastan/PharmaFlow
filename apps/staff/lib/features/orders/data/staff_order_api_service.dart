import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/auth/staff_auth_token_storage.dart';
import 'staff_order.dart';

class StaffOrderApiException implements Exception {
  const StaffOrderApiException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class StaffOrderApiService {
  static const String _baseUrl = String.fromEnvironment(
    'PHARMAFLOW_API_BASE_URL',
    defaultValue: 'https://naughty-haslett-zvtszb2yr.liara.run/api/v1',
  );

  StaffOrderApiService({
    http.Client? httpClient,
    StaffAuthTokenStorage? authStorage,
  }) : _httpClient = httpClient ?? http.Client(),
       _authStorage = authStorage ?? StaffAuthTokenStorage();

  final http.Client _httpClient;
  final StaffAuthTokenStorage _authStorage;

  Future<List<StaffOrder>> fetchActiveOrders() async {
    final uri = Uri.parse('$_baseUrl/orders');
    final response = await _httpClient
        .get(uri, headers: await _authorizedHeaders())
        .timeout(const Duration(seconds: 25));
    final responseBody = utf8.decode(response.bodyBytes);

    _throwForError(response.statusCode, responseBody);

    final decoded = jsonDecode(responseBody);

    if (decoded is! List) {
      throw const FormatException('Order list response is not a JSON array.');
    }

    return decoded
        .whereType<Map>()
        .map((item) => StaffOrder.fromJson(Map<String, dynamic>.from(item)))
        .where((order) => order.isPending || order.isOrdered)
        .toList(growable: false);
  }

  Future<StaffOrder> receiveOrder({required String orderId}) async {
    final response = await _postJson('/orders/$orderId/receive', body: {});
    return StaffOrder.fromJson(response);
  }

  Future<StaffOrder> updatePendingOrder({
    required String orderId,
    required String category,
    required String itemText,
    int? requestedQuantity,
    String? suggestedCompanyText,
    String? notes,
  }) async {
    final response = await _postJson(
      '/orders/$orderId/edit',
      body: {
        'category': category,
        'itemText': itemText,
        'requestedQuantity': requestedQuantity,
        'suggestedCompanyText': _nullIfBlank(suggestedCompanyText),
        'notes': _nullIfBlank(notes),
      },
    );

    return StaffOrder.fromJson(response);
  }

  Future<void> deletePendingOrder({required String orderId}) async {
    await _deleteJson('/orders/$orderId');
  }

  Future<Map<String, dynamic>> checkDuplicate({
    required String category,
    required String itemText,
  }) async {
    return _postJson(
      '/orders/duplicate-check',
      body: {'category': category, 'itemText': itemText},
    );
  }

  Future<Map<String, dynamic>> createOrder({
    required String category,
    required String itemText,
    int? requestedQuantity,
    String? suggestedCompanyText,
    String? notes,
  }) async {
    return _postJson(
      '/orders',
      body: {
        'category': category,
        'itemText': itemText,
        'requestedQuantity': requestedQuantity,
        'suggestedCompanyText': _nullIfBlank(suggestedCompanyText),
        'notes': _nullIfBlank(notes),
      },
    );
  }

  Future<Map<String, dynamic>> updateCategory({
    required String orderId,
    required String category,
  }) async {
    return _postJson('/orders/$orderId/category', body: {'category': category});
  }

  Future<Map<String, dynamic>> preparePhoto({
    required String orderId,
    required int fileSize,
  }) async {
    return _postJson(
      '/orders/$orderId/photo/prepare',
      body: {'mimeType': 'image/jpeg', 'fileSize': fileSize},
    );
  }

  Future<void> uploadPhotoBytes({
    required String uploadUrl,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse(uploadUrl);
    final response = await _httpClient
        .put(uri, headers: const {'Content-Type': 'image/jpeg'}, body: bytes)
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StaffOrderApiException(
        statusCode: response.statusCode,
        message: 'Photo upload failed with HTTP ${response.statusCode}.',
      );
    }
  }

  Future<Map<String, dynamic>> uploadWebPhoto({
    required String orderId,
    required Uint8List bytes,
    required String sha256,
  }) async {
    return _postJson(
      '/orders/$orderId/photo/upload-web',
      body: {
        'mimeType': 'image/jpeg',
        'fileSize': bytes.length,
        'sha256': sha256,
        'imageBase64': base64Encode(bytes),
      },
      timeout: const Duration(seconds: 45),
    );
  }

  Future<Map<String, dynamic>> confirmPhoto({
    required String orderId,
    required int fileSize,
    required String sha256,
  }) async {
    return _postJson(
      '/orders/$orderId/photo/confirm',
      body: {'mimeType': 'image/jpeg', 'fileSize': fileSize, 'sha256': sha256},
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = await _authorizedHeaders();
    headers['Content-Type'] = 'application/json; charset=utf-8';

    final response = await _httpClient
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);
    final responseBody = utf8.decode(response.bodyBytes);

    _throwForError(response.statusCode, responseBody);

    if (responseBody.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Server response is not a JSON object.');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient
        .delete(uri, headers: await _authorizedHeaders())
        .timeout(const Duration(seconds: 25));
    final responseBody = utf8.decode(response.bodyBytes);

    _throwForError(response.statusCode, responseBody);

    if (responseBody.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Server response is not a JSON object.');
    }

    return decoded;
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await _authStorage.readToken();

    if (token == null || token.isEmpty) {
      throw const StaffOrderApiException(
        statusCode: 401,
        message: 'Authentication session is missing.',
      );
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwForError(int statusCode, String responseBody) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }

    var message = responseBody.isEmpty
        ? 'Server returned HTTP $statusCode.'
        : responseBody;

    if (responseBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(responseBody);

        if (decoded is Map<String, dynamic>) {
          final rawMessage = decoded['message'];

          if (rawMessage is String && rawMessage.trim().isNotEmpty) {
            message = rawMessage;
          } else if (rawMessage is List && rawMessage.isNotEmpty) {
            message = rawMessage.join('\n');
          }
        }
      } catch (_) {
        // Preserve the original response body.
      }
    }

    throw StaffOrderApiException(statusCode: statusCode, message: message);
  }

  String? _nullIfBlank(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  void close() {
    _httpClient.close();
  }
}
