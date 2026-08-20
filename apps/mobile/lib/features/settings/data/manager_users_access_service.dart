import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';

class ManagerUserPermissions {
  const ManagerUserPermissions({
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

  factory ManagerUserPermissions.fromJson(Map<String, dynamic> json) {
    return ManagerUserPermissions(
      managerAppAccess: json['managerAppAccess'] == true,
      canCreateOrders: json['canCreateOrders'] != false,
      canCreateCheques: json['canCreateCheques'] == true,
      canCreateCashPayments: json['canCreateCashPayments'] == true,
      canViewFinancialReports: json['canViewFinancialReports'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'managerAppAccess': managerAppAccess,
      'canCreateOrders': canCreateOrders,
      'canCreateCheques': canCreateCheques,
      'canCreateCashPayments': canCreateCashPayments,
      'canViewFinancialReports': canViewFinancialReports,
    };
  }

  ManagerUserPermissions copyWith({
    bool? managerAppAccess,
    bool? canCreateOrders,
    bool? canCreateCheques,
    bool? canCreateCashPayments,
    bool? canViewFinancialReports,
  }) {
    return ManagerUserPermissions(
      managerAppAccess: managerAppAccess ?? this.managerAppAccess,
      canCreateOrders: canCreateOrders ?? this.canCreateOrders,
      canCreateCheques: canCreateCheques ?? this.canCreateCheques,
      canCreateCashPayments:
          canCreateCashPayments ?? this.canCreateCashPayments,
      canViewFinancialReports:
          canViewFinancialReports ?? this.canViewFinancialReports,
    );
  }

  static const ManagerUserPermissions staffDefaults = ManagerUserPermissions(
    managerAppAccess: false,
    canCreateOrders: true,
    canCreateCheques: false,
    canCreateCashPayments: false,
    canViewFinancialReports: false,
  );

  static const ManagerUserPermissions managerFull = ManagerUserPermissions(
    managerAppAccess: true,
    canCreateOrders: true,
    canCreateCheques: true,
    canCreateCashPayments: true,
    canViewFinancialReports: true,
  );
}

class ManagedAppUser {
  const ManagedAppUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.permissions,
  });

  final String userId;
  final String username;
  final String displayName;
  final String role;
  final bool isActive;
  final ManagerUserPermissions permissions;

  bool get isManager => role == 'MANAGER';

  factory ManagedAppUser.fromJson(Map<String, dynamic> json) {
    final permissionsRaw = json['permissions'];

    return ManagedAppUser(
      userId: _requiredString(json, 'userId'),
      username: _requiredString(json, 'username'),
      displayName: _requiredString(json, 'displayName'),
      role: _requiredString(json, 'role'),
      isActive: json['isActive'] == true,
      permissions: permissionsRaw is Map<String, dynamic>
          ? ManagerUserPermissions.fromJson(permissionsRaw)
          : roleFromJson(json) == 'MANAGER'
          ? ManagerUserPermissions.managerFull
          : ManagerUserPermissions.staffDefaults,
    );
  }

  static String roleFromJson(Map<String, dynamic> json) {
    return _requiredString(json, 'role');
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('User field $key is missing.');
    }

    return value.trim();
  }
}

class ManagerUserActivity {
  const ManagerUserActivity({
    required this.createdAt,
    required this.actorDisplayName,
    required this.action,
    required this.entityType,
    required this.entityId,
  });

  final DateTime? createdAt;
  final String actorDisplayName;
  final String action;
  final String entityType;
  final String? entityId;

  factory ManagerUserActivity.fromJson(Map<String, dynamic> json) {
    return ManagerUserActivity(
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      actorDisplayName: '${json['actorDisplayName'] ?? ''}'.trim(),
      action: '${json['action'] ?? ''}'.trim(),
      entityType: '${json['entityType'] ?? ''}'.trim(),
      entityId: json['entityId']?.toString(),
    );
  }
}

class ManagerUsersAccessService {
  const ManagerUsersAccessService({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ManagedAppUser> me() async {
    final payload = await _apiClient.get(ApiConstants.authMeEndpoint);

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Current user response is invalid.');
    }

    final rawUser = payload['user'];

    if (rawUser is! Map<String, dynamic>) {
      throw const FormatException('Current user response is incomplete.');
    }

    return ManagedAppUser.fromJson(rawUser);
  }

  Future<List<ManagedAppUser>> listUsers() async {
    final payload = await _apiClient.get(ApiConstants.authUsersEndpoint);

    if (payload is! List<dynamic>) {
      throw const FormatException('Users response is not a list.');
    }

    return payload
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('User row is invalid.');
          }

          return ManagedAppUser.fromJson(item);
        })
        .toList(growable: false);
  }

  Future<ManagedAppUser> createUser({
    required String username,
    required String displayName,
    required String password,
    required String role,
    required ManagerUserPermissions permissions,
  }) async {
    final payload = await _apiClient.post(
      ApiConstants.authUsersEndpoint,
      body: <String, dynamic>{
        'username': username.trim(),
        'displayName': displayName.trim(),
        'password': password,
        'role': role,
        ...permissions.toJson(),
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Create user response is invalid.');
    }

    return ManagedAppUser.fromJson(payload);
  }

  Future<ManagedAppUser> setActive({
    required String userId,
    required bool isActive,
  }) async {
    final payload = await _apiClient.post(
      '${ApiConstants.authUsersEndpoint}/${Uri.encodeComponent(userId)}/active',
      body: <String, dynamic>{'isActive': isActive},
    );

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Set active response is invalid.');
    }

    return ManagedAppUser.fromJson(payload);
  }

  Future<ManagedAppUser> setPermissions({
    required String userId,
    required ManagerUserPermissions permissions,
  }) async {
    final payload = await _apiClient.post(
      '${ApiConstants.authUsersEndpoint}/${Uri.encodeComponent(userId)}/permissions',
      body: permissions.toJson(),
    );

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Set permissions response is invalid.');
    }

    return ManagedAppUser.fromJson(payload);
  }

  Future<void> resetPassword({
    required String userId,
    required String password,
  }) async {
    await _apiClient.post(
      '${ApiConstants.authUsersEndpoint}/${Uri.encodeComponent(userId)}/reset-password',
      body: <String, dynamic>{'password': password},
    );
  }

  Future<List<ManagerUserActivity>> listActivity(String userId) async {
    final payload = await _apiClient.get(
      '${ApiConstants.authUsersEndpoint}/${Uri.encodeComponent(userId)}/activity',
      queryParameters: const <String, String>{'limit': '100'},
    );

    if (payload is! List<dynamic>) {
      throw const FormatException('User activity response is not a list.');
    }

    return payload
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Activity row is invalid.');
          }

          return ManagerUserActivity.fromJson(item);
        })
        .toList(growable: false);
  }
}
