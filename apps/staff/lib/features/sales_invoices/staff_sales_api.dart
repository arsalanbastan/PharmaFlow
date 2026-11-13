import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sales_invoices_ui/sales_api.dart';

import '../../core/auth/staff_auth_token_storage.dart';

class StaffSalesApi extends SalesApi {
  factory StaffSalesApi() => StaffSalesApi._(_StaffSalesTransport());

  StaffSalesApi._(this._transport)
    : super(_transport.request, canManage: _transport.canManage);

  final _StaffSalesTransport _transport;

  @override
  void close() => _transport.close();
}

class _StaffSalesTransport {
  static const _base = String.fromEnvironment(
    'PHARMAFLOW_API_BASE_URL',
    defaultValue: 'https://naughty-haslett-zvtszb2yr.liara.run/api/v1',
  );
  final _client = http.Client();
  final _storage = StaffAuthTokenStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty)
      throw StateError('لطفاً دوباره وارد شوید.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
  }) async {
    final uri = Uri.parse('$_base$path');
    final headers = await _headers();
    final response = method == 'PUT'
        ? await _client
              .put(uri, headers: headers, body: jsonEncode(body ?? const {}))
              .timeout(const Duration(seconds: 25))
        : body == null
        ? await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 25))
        : await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'خطای سرور (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
      );
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  Future<bool> canManage() async =>
      (await _storage.load())?.user.role == 'MANAGER';

  void close() => _client.close();
}
