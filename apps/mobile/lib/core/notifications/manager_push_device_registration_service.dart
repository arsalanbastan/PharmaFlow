import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_constants.dart';

enum ManagerNotificationMode {
  audible,
  silent,
  off;

  String get apiValue => switch (this) {
    ManagerNotificationMode.audible => 'AUDIBLE',
    ManagerNotificationMode.silent => 'SILENT',
    ManagerNotificationMode.off => 'OFF',
  };

  static ManagerNotificationMode fromApi(Object? value) {
    return switch (value?.toString()) {
      'SILENT' => ManagerNotificationMode.silent,
      'OFF' => ManagerNotificationMode.off,
      _ => ManagerNotificationMode.audible,
    };
  }
}

class ManagerNotificationPreferences {
  const ManagerNotificationPreferences({
    required this.notificationsEnabled,
    required this.orderMode,
    required this.chequeMode,
    required this.cashPaymentMode,
  });

  final bool notificationsEnabled;
  final ManagerNotificationMode orderMode;
  final ManagerNotificationMode chequeMode;
  final ManagerNotificationMode cashPaymentMode;

  factory ManagerNotificationPreferences.fromJson(Map<String, dynamic> json) {
    return ManagerNotificationPreferences(
      notificationsEnabled: json['notificationsEnabled'] != false,
      orderMode: ManagerNotificationMode.fromApi(json['orderNotificationMode']),
      chequeMode: ManagerNotificationMode.fromApi(
        json['chequeNotificationMode'],
      ),
      cashPaymentMode: ManagerNotificationMode.fromApi(
        json['cashPaymentNotificationMode'],
      ),
    );
  }
}

class ManagerPushDeviceRegistrationService {
  ManagerPushDeviceRegistrationService({
    required ApiClient apiClient,
    Future<String?> Function()? fcmTokenProvider,
    Future<String> Function()? installationIdProvider,
    String? appPackageOverride,
  }) : _apiClient = apiClient,
       _fcmTokenProvider = fcmTokenProvider ?? _readFirebaseToken,
       _installationIdProvider =
           installationIdProvider ?? _loadOrCreateInstallationId,
       _appPackage =
           appPackageOverride ??
           (kDebugMode
               ? 'com.example.pharmaflow.dev'
               : 'com.example.pharmaflow');

  static const String _installationIdKey = 'manager_push_installation_id_v1';

  final ApiClient _apiClient;
  final Future<String?> Function() _fcmTokenProvider;
  final Future<String> Function() _installationIdProvider;
  final String _appPackage;

  Future<bool> registerCurrentToken() async {
    final token = await _fcmTokenProvider();
    if (token == null || token.trim().isEmpty) {
      return false;
    }

    return registerToken(token);
  }

  Future<bool> registerToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return false;
    }

    final installationId = await _installationIdProvider();

    await _apiClient.post(
      ApiConstants.pushDeviceRegisterEndpoint,
      body: <String, dynamic>{
        'token': normalizedToken,
        'installationId': installationId,
        'platform': 'android',
        'appPackage': _appPackage,
        'notificationAggregationVersion': 1,
      },
    );

    if (kDebugMode) {
      debugPrint('PHARMAFLOW_PUSH_DEVICE_REGISTERED=1');
    }

    return true;
  }

  Future<ManagerNotificationPreferences> loadNotificationPreferences() async {
    final installationId = await _installationIdProvider();

    final response = await _apiClient.post(
      ApiConstants.pushDevicePreferencesReadEndpoint,
      body: <String, dynamic>{
        'installationId': installationId,
        'appPackage': _appPackage,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw StateError('Notification preferences response is invalid.');
    }

    return ManagerNotificationPreferences.fromJson(response);
  }

  Future<ManagerNotificationPreferences> updateNotificationPreferences(
    ManagerNotificationPreferences preferences,
  ) async {
    final installationId = await _installationIdProvider();

    final response = await _apiClient.patch(
      ApiConstants.pushDevicePreferencesEndpoint,
      body: <String, dynamic>{
        'installationId': installationId,
        'appPackage': _appPackage,
        'notificationsEnabled': preferences.notificationsEnabled,
        'orderNotificationMode': preferences.orderMode.apiValue,
        'chequeNotificationMode': preferences.chequeMode.apiValue,
        'cashPaymentNotificationMode': preferences.cashPaymentMode.apiValue,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw StateError('Updated notification preferences response is invalid.');
    }

    return ManagerNotificationPreferences.fromJson(response);
  }

  Future<bool> acknowledgeNotification(String deliveryId) async {
    final normalizedDeliveryId = deliveryId.trim();

    if (normalizedDeliveryId.isEmpty) {
      return false;
    }

    await _apiClient.post(
      ApiConstants.pushNotificationAcknowledgeEndpoint,
      body: <String, dynamic>{'deliveryId': normalizedDeliveryId},
    );

    return true;
  }

  Future<bool> acknowledgeAllNotifications() async {
    final installationId = await _installationIdProvider();

    await _apiClient.post(
      ApiConstants.pushNotificationsAcknowledgeAllEndpoint,
      body: <String, dynamic>{
        'installationId': installationId,
        'appPackage': _appPackage,
      },
    );

    return true;
  }

  Future<bool> unregister() async {
    final installationId = await _installationIdProvider();

    await _apiClient.post(
      ApiConstants.pushDeviceUnregisterEndpoint,
      body: <String, dynamic>{
        'installationId': installationId,
        'appPackage': _appPackage,
      },
    );

    if (kDebugMode) {
      debugPrint('PHARMAFLOW_PUSH_DEVICE_UNREGISTERED=1');
    }

    return true;
  }

  static Future<String?> _readFirebaseToken() {
    return FirebaseMessaging.instance.getToken();
  }

  static Future<String> _loadOrCreateInstallationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_installationIdKey)?.trim();

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();

    await preferences.setString(_installationIdKey, id);
    return id;
  }
}
