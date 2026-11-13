import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sales_invoices_ui/staff_pos_bridge.dart';

Future<StaffPosBridgeResult> managerSalesPosBridgeRequest({
  required String baseUrl,
  required String path,
  String method = 'GET',
  Map<String, dynamic>? body,
  int timeoutMs = 5000,
  String grant = '',
}) async {
  final base = Uri.tryParse(baseUrl);
  final parts = base?.host.split('.').map(int.tryParse).toList();
  if (base == null ||
      base.scheme != 'http' ||
      parts == null ||
      parts.length != 4 ||
      parts.any((part) => part == null || part < 0 || part > 255) ||
      !(parts[0] == 10 ||
          (parts[0] == 192 && parts[1] == 168) ||
          (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31))) {
    return const StaffPosBridgeResult({
      'ok': false,
      'code': 'INVALID_BRIDGE_HOST',
      'error': 'آدرس POS Bridge باید IP خصوصی شبکه داروخانه باشد.',
    });
  }

  final client = HttpClient();
  try {
    final result = await (() async {
      final request = await client.openUrl(method, base.replace(path: path));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-PharmaFlow-Bridge', '1');
      if (grant.isNotEmpty) request.headers.set('X-PharmaFlow-Grant', grant);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final decoded = jsonDecode(await response.transform(utf8.decoder).join());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid POS bridge response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        decoded['ok'] = false;
      }
      return StaffPosBridgeResult(decoded);
    })().timeout(Duration(milliseconds: timeoutMs));
    return result;
  } on TimeoutException {
    return const StaffPosBridgeResult({'ok': false, 'code': 'BRIDGE_TIMEOUT'});
  } on FormatException {
    return const StaffPosBridgeResult({
      'ok': false,
      'code': 'INVALID_BRIDGE_RESPONSE',
    });
  } catch (_) {
    return const StaffPosBridgeResult({'ok': false, 'code': 'BRIDGE_OFFLINE'});
  } finally {
    client.close(force: true);
  }
}
