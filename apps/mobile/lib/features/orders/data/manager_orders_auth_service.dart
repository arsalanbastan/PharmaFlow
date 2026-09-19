import 'dart:async';

import '../../../core/auth/auth_token_storage.dart';
import '../../../core/notifications/manager_push_device_registration_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';

class ManagerOrdersAuthPermissions {
  const ManagerOrdersAuthPermissions({
    required this.managerAppAccess,
    required this.canCreateOrders,
    required this.canCreateCheques,
    required this.canCreateCashPayments,
    required this.canViewFinancialReports,
  });

  final bool managerAppAccess;
  final bool canCreateOrders;
  final bool canCreateCheques;
  final bool canCreateCashPayments;
  final bool canViewFinancialReports;

  static const ManagerOrdersAuthPermissions managerFull =
      ManagerOrdersAuthPermissions(
        managerAppAccess: true,
        canCreateOrders: true,
        canCreateCheques: true,
        canCreateCashPayments: true,
        canViewFinancialReports: true,
      );

  static const ManagerOrdersAuthPermissions staffDefaults =
      ManagerOrdersAuthPermissions(
        managerAppAccess: false,
        canCreateOrders: true,
        canCreateCheques: false,
        canCreateCashPayments: false,
        canViewFinancialReports: false,
      );

  factory ManagerOrdersAuthPermissions.fromJson(
    Object? raw, {
    required String role,
  }) {
    if (role == 'MANAGER') {
      return managerFull;
    }

    if (raw is! Map<String, dynamic>) {
      return staffDefaults;
    }

    return ManagerOrdersAuthPermissions(
      managerAppAccess: raw['managerAppAccess'] == true,
      canCreateOrders: raw['canCreateOrders'] != false,
      canCreateCheques: raw['canCreateCheques'] == true,
      canCreateCashPayments: raw['canCreateCashPayments'] == true,
      canViewFinancialReports: raw['canViewFinancialReports'] == true,
    );
  }
}

class ManagerOrdersAuthUser {
  const ManagerOrdersAuthUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.permissions,
  });

  final String userId;
  final String username;
  final String displayName;
  final String role;
  final ManagerOrdersAuthPermissions permissions;

  bool get isManager => role == 'MANAGER';

  bool get canUseManagerApp => isManager || permissions.managerAppAccess;

  factory ManagerOrdersAuthUser.fromJson(Map<String, dynamic> json) {
    final role = _requiredString(json, 'role');

    return ManagerOrdersAuthUser(
      userId: _requiredString(json, 'userId'),
      username: _requiredString(json, 'username'),
      displayName: _requiredString(json, 'displayName'),
      role: role,
      permissions: ManagerOrdersAuthPermissions.fromJson(
        json['permissions'],
        role: role,
      ),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final raw = json[key];

    if (raw is! String || raw.trim().isEmpty) {
      throw FormatException('Auth user field $key is missing.');
    }

    return raw.trim();
  }
}

class ManagerOrdersAuthException implements Exception {
  const ManagerOrdersAuthException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ManagerOrdersAuthService {
  const ManagerOrdersAuthService({
    required ApiClient apiClient,
    required AuthTokenStorage tokenStorage,
    ManagerPushDeviceRegistrationService? pushDevices,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage,
       _pushDevices = pushDevices;

  final ApiClient _apiClient;
  final AuthTokenStorage _tokenStorage;
  final ManagerPushDeviceRegistrationService? _pushDevices;

  Future<ManagerOrdersAuthUser> login({
    required String username,
    required String password,
  }) async {
    final payload = await _apiClient.post(
      ApiConstants.authLoginEndpoint,
      body: <String, dynamic>{
        'username': username.trim(),
        'password': password,
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Login response is not a JSON object.');
    }

    final tokenRaw = payload['token'];
    final userRaw = payload['user'];

    if (tokenRaw is! String ||
        tokenRaw.trim().isEmpty ||
        userRaw is! Map<String, dynamic>) {
      throw const FormatException('Login response is incomplete.');
    }

    final user = ManagerOrdersAuthUser.fromJson(userRaw);

    if (!user.canUseManagerApp) {
      throw const ManagerOrdersAuthException(
        statusCode: 403,
        message: 'این حساب اجازه ورود به اپ Manager را ندارد.',
      );
    }

    await _tokenStorage.saveToken(tokenRaw.trim());

    if (user.isManager) {
      _schedulePushRegistration();
    }

    return user;
  }

  Future<ManagerOrdersAuthUser> me() async {
    final payload = await _apiClient.get(ApiConstants.authMeEndpoint);

    if (payload is! Map<String, dynamic>) {
      throw const FormatException(
        'Current user response is not a JSON object.',
      );
    }

    final userRaw = payload['user'];

    if (userRaw is! Map<String, dynamic>) {
      throw const FormatException('Current user response is incomplete.');
    }

    final user = ManagerOrdersAuthUser.fromJson(userRaw);

    if (!user.canUseManagerApp) {
      throw const ManagerOrdersAuthException(
        statusCode: 403,
        message: 'این حساب دیگر اجازه ورود به اپ Manager را ندارد.',
      );
    }

    if (user.isManager) {
      _schedulePushRegistration();
    }

    return user;
  }

  Future<void> logout() async {
    try {
      await _unregisterPushBestEffort();

      await _apiClient.post(
        ApiConstants.authLogoutEndpoint,
        body: const <String, dynamic>{},
      );
    } finally {
      await _tokenStorage.deleteToken();
    }
  }

  Future<void> clearLocalSession() {
    return _tokenStorage.deleteToken();
  }

  void _schedulePushRegistration() {
    final pushDevices = _pushDevices;

    if (pushDevices == null) {
      return;
    }

    unawaited(_registerPushBestEffort(pushDevices));
  }

  Future<void> _registerPushBestEffort(
    ManagerPushDeviceRegistrationService pushDevices,
  ) async {
    try {
      await pushDevices.registerCurrentToken();
    } catch (_) {
      // Push registration must never block Manager authentication.
    }
  }

  Future<void> _unregisterPushBestEffort() async {
    final pushDevices = _pushDevices;

    if (pushDevices == null) {
      return;
    }

    try {
      await pushDevices.unregister();
    } catch (_) {
      // Logout must continue even if device revocation cannot reach the server.
    }
  }
}
