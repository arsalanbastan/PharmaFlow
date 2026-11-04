class StaffPosBridgeResult {
  const StaffPosBridgeResult(this.data);
  final Map<String, dynamic> data;
  bool get ok => data['ok'] == true;
  String get responseCode => '${data['responseCode'] ?? data['code'] ?? ''}';
  String get description => '${data['responseDescription'] ?? data['error'] ?? ''}';
}

Future<StaffPosBridgeResult> staffPosBridgeRequest({
  required String baseUrl,
  required String path,
  String method = 'GET',
  Map<String, dynamic>? body,
  int timeoutMs = 5000,
  String grant = '',
}) async {
  return const StaffPosBridgeResult({
    'ok': false,
    'code': 'WEB_ONLY',
    'error': 'اتصال مستقیم به پوز فعلاً فقط در Staff Web فعال است.',
  });
}
