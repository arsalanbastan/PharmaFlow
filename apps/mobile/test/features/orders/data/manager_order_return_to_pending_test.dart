import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/features/orders/data/manager_orders_repository.dart';

class _FakeApiClient extends ApiClient {
  String? lastPostEndpoint;
  Object? lastPostBody;

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
  }) async {
    lastPostEndpoint = endpoint;
    lastPostBody = body;
    return <String, dynamic>{'ok': true};
  }
}

void main() {
  test('returnToPending posts to the manager return endpoint', () async {
    final api = _FakeApiClient();
    final repository = ManagerOrdersRepository(api);

    await repository.returnToPending(
      orderId: '33333333-3333-4333-8333-333333333333',
    );

    expect(
      api.lastPostEndpoint,
      '/orders/33333333-3333-4333-8333-333333333333/return-to-pending',
    );
    expect(api.lastPostBody, isNull);
  });

  test(
    'returnToPending rejects a blank order id before API mutation',
    () async {
      final api = _FakeApiClient();
      final repository = ManagerOrdersRepository(api);

      await expectLater(
        repository.returnToPending(orderId: '   '),
        throwsArgumentError,
      );

      expect(api.lastPostEndpoint, isNull);
    },
  );
}
