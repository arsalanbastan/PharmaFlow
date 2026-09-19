import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/auth/auth_token_storage.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/features/orders/data/manager_orders_auth_service.dart';

class _MemoryTokenStorage extends AuthTokenStorage {
  String? token;

  @override
  Future<void> saveToken(String token) async {
    this.token = token;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> deleteToken() async {
    token = null;
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.postPayload, this.getPayload});

  dynamic postPayload;
  dynamic getPayload;
  String? lastPostEndpoint;
  String? lastGetEndpoint;

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
  }) async {
    lastPostEndpoint = endpoint;
    return postPayload;
  }

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    lastGetEndpoint = endpoint;
    return getPayload;
  }
}

void main() {
  test('manager login stores opaque token only for MANAGER role', () async {
    final api = _FakeApiClient(
      postPayload: <String, dynamic>{
        'token': 'opaque-manager-session-token',
        'user': <String, dynamic>{
          'userId': '11111111-1111-4111-8111-111111111111',
          'username': 'manager',
          'displayName': 'مدیر',
          'role': 'MANAGER',
        },
      },
    );
    final storage = _MemoryTokenStorage();
    final service = ManagerOrdersAuthService(
      apiClient: api,
      tokenStorage: storage,
    );

    final user = await service.login(
      username: ' manager ',
      password: 'secret-123',
    );

    expect(user.isManager, isTrue);
    expect(storage.token, 'opaque-manager-session-token');
    expect(api.lastPostEndpoint, '/auth/login');
  });

  test('manager login rejects STAFF role without storing token', () async {
    final api = _FakeApiClient(
      postPayload: <String, dynamic>{
        'token': 'staff-token',
        'user': <String, dynamic>{
          'userId': '22222222-2222-4222-8222-222222222222',
          'username': 'staff',
          'displayName': 'کارمند',
          'role': 'STAFF',
        },
      },
    );
    final storage = _MemoryTokenStorage();
    final service = ManagerOrdersAuthService(
      apiClient: api,
      tokenStorage: storage,
    );

    await expectLater(
      service.login(username: 'staff', password: 'secret-123'),
      throwsA(isA<ManagerOrdersAuthException>()),
    );

    expect(storage.token, isNull);
  });

  test('me requires manager role from backend identity', () async {
    final api = _FakeApiClient(
      getPayload: <String, dynamic>{
        'user': <String, dynamic>{
          'userId': '33333333-3333-4333-8333-333333333333',
          'username': 'manager',
          'displayName': 'مدیر',
          'role': 'MANAGER',
        },
      },
    );
    final service = ManagerOrdersAuthService(
      apiClient: api,
      tokenStorage: _MemoryTokenStorage(),
    );

    final user = await service.me();

    expect(user.role, 'MANAGER');
    expect(api.lastGetEndpoint, '/auth/me');
  });
}
