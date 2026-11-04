import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/staff_auth_token_storage.dart';

class StaffPosDevice {
  const StaffPosDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.terminalId,
    required this.timeout,
    required this.enabled,
  });

  final String id;
  final String name;
  final String ip;
  final String terminalId;
  final int timeout;
  final bool enabled;

  factory StaffPosDevice.fromJson(Map<String, dynamic> json) => StaffPosDevice(
        id: '${json['id'] ?? ''}'.trim(),
        name: '${json['name'] ?? ''}'.trim(),
        ip: '${json['ip'] ?? ''}'.trim(),
        terminalId: '${json['terminalId'] ?? ''}'.trim(),
        timeout: int.tryParse('${json['timeout'] ?? 60}') ?? 60,
        enabled: json['enabled'] != false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'terminalId': terminalId,
        'timeout': timeout,
        'enabled': enabled,
      };

  StaffPosDevice copyWith({
    String? id,
    String? name,
    String? ip,
    String? terminalId,
    int? timeout,
    bool? enabled,
  }) =>
      StaffPosDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        ip: ip ?? this.ip,
        terminalId: terminalId ?? this.terminalId,
        timeout: timeout ?? this.timeout,
        enabled: enabled ?? this.enabled,
      );
}

class StaffPosSettings {
  const StaffPosSettings({
    required this.bridgeHost,
    required this.bridgePort,
    required this.devices,
  });

  final String bridgeHost;
  final int bridgePort;
  final List<StaffPosDevice> devices;

  String get bridgeBaseUrl => 'http://$bridgeHost:$bridgePort';

  factory StaffPosSettings.fromJson(Map<String, dynamic> json) => StaffPosSettings(
        bridgeHost: '${json['bridgeHost'] ?? ''}'.trim(),
        bridgePort: int.tryParse('${json['bridgePort'] ?? 17905}') ?? 17905,
        devices: ((json['devices'] as List?) ?? const [])
            .whereType<Map>()
            .map((value) => StaffPosDevice.fromJson(Map<String, dynamic>.from(value)))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'bridgeHost': bridgeHost.isEmpty ? null : bridgeHost,
        'bridgePort': bridgePort,
        'devices': devices.map((value) => value.toJson()).toList(),
      };
}

class StaffSettingsApi {
  static const String _base = String.fromEnvironment(
    'PHARMAFLOW_API_BASE_URL',
    defaultValue: 'https://naughty-haslett-zvtszb2yr.liara.run/api/v1',
  );

  StaffSettingsApi({http.Client? client, StaffAuthTokenStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? StaffAuthTokenStorage();

  final http.Client _client;
  final StaffAuthTokenStorage _storage;

  Future<StaffPosSettings> posSettings() async {
    return StaffPosSettings.fromJson(await _request('/staff-settings/pos'));
  }

  Future<StaffPosSettings> updatePosSettings(StaffPosSettings settings) async {
    return StaffPosSettings.fromJson(
      await _request('/staff-settings/pos', method: 'PUT', body: settings.toJson()),
    );
  }

  Future<String> requestPosGrant({
    required String operation,
    required String deviceId,
    required String requestId,
    required int amount,
  }) async {
    final data = await _request('/staff-settings/pos/grant', method: 'POST', body: {
      'operation': operation,
      'deviceId': deviceId,
      'requestId': requestId,
      'amount': amount,
    });
    final grant = '${data['grant'] ?? ''}';
    if (grant.isEmpty) throw StateError('مجوز امن پرداخت صادر نشد.');
    return grant;
  }

  Future<Map<String, dynamic>> verifyPosReceipt({
    required String receipt,
    required String deviceId,
    required int amount,
  }) => _request('/staff-settings/pos/verify-receipt', method: 'POST', body: {
        'receipt': receipt,
        'deviceId': deviceId,
        'amount': amount,
      });

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('لطفاً دوباره وارد شوید.');
    }

    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    if (body != null) headers['Content-Type'] = 'application/json; charset=utf-8';

    final uri = Uri.parse('$_base$path');
    late http.Response response;
    if (method == 'POST') {
      response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? const {}))
          .timeout(const Duration(seconds: 25));
    } else if (method == 'PUT') {
      response = await _client
          .put(uri, headers: headers, body: jsonEncode(body ?? const {}))
          .timeout(const Duration(seconds: 25));
    } else {
      response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 25));
    }

    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('خطای سرور (${response.statusCode}): $text');
    }
    if (text.trim().isEmpty) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(text) as Map);
  }

  void close() => _client.close();
}
