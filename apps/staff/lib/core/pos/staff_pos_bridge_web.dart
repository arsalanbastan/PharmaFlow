import 'dart:convert';
import 'dart:js_interop';

class StaffPosBridgeResult {
  const StaffPosBridgeResult(this.data);
  final Map<String, dynamic> data;
  bool get ok => data['ok'] == true;
  String get responseCode => '${data['responseCode'] ?? data['code'] ?? ''}';
  String get description => '${data['responseDescription'] ?? data['error'] ?? ''}';
}

@JS('PharmaFlowPosBridge.request')
external JSPromise<JSString> _request(
  JSString baseUrl,
  JSString path,
  JSString method,
  JSString bodyJson,
  JSNumber timeoutMs,
  JSString grant,
);

Future<StaffPosBridgeResult> staffPosBridgeRequest({
  required String baseUrl,
  required String path,
  String method = 'GET',
  Map<String, dynamic>? body,
  int timeoutMs = 5000,
  String grant = '',
}) async {
  try {
    final raw = await _request(
      baseUrl.toJS,
      path.toJS,
      method.toJS,
      jsonEncode(body).toJS,
      timeoutMs.toJS,
      grant.toJS,
    ).toDart;
    final decoded = jsonDecode(raw.toDart);
    if (decoded is Map) {
      return StaffPosBridgeResult(Map<String, dynamic>.from(decoded));
    }
    return const StaffPosBridgeResult({
      'ok': false,
      'code': 'INVALID_BRIDGE_RESPONSE',
      'error': 'پاسخ POS Bridge معتبر نبود.',
    });
  } catch (_) {
    return const StaffPosBridgeResult({
      'ok': false,
      'code': 'BRIDGE_OFFLINE',
      'error': 'به شبکه داروخانه متصل نیستید.',
    });
  }
}
