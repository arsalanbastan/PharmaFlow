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
    return <String, dynamic>{
      'id': '9d5eaa73-4c17-467e-995f-2af4a428b5a1',
      'category': 'DRUG',
      'itemText': 'داروی تست',
      'status': 'ORDERED',
      'requestedByName': 'مریم',
      'createdAt': '2026-11-13T08:00:00Z',
      'orderedQuantity': 2,
      'assignedCompany': <String, dynamic>{
        'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'name': 'داروپخش',
      },
    };
  }
}

void main() {
  test('assign posts company id and quantity to manager endpoint', () async {
    final api = _FakeApiClient();
    final repository = ManagerOrdersRepository(api);

    final order = await repository.assign(
      orderId: '9d5eaa73-4c17-467e-995f-2af4a428b5a1',
      companyId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      quantity: 2,
    );

    expect(order.status, 'ORDERED');
    expect(order.assignedCompanyName, 'داروپخش');
    expect(order.orderedQuantity, 2);
    expect(
      api.lastPostEndpoint,
      '/orders/9d5eaa73-4c17-467e-995f-2af4a428b5a1/assign',
    );
    expect(api.lastPostBody, <String, dynamic>{
      'companyId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'quantity': 2,
    });
  });

  test('assign omits optional quantity when manager leaves it blank', () async {
    final api = _FakeApiClient();
    final repository = ManagerOrdersRepository(api);

    await repository.assign(
      orderId: '9d5eaa73-4c17-467e-995f-2af4a428b5a1',
      companyId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );

    expect(api.lastPostBody, <String, dynamic>{
      'companyId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    });
  });

  test('assign rejects invalid quantity before API mutation', () async {
    final api = _FakeApiClient();
    final repository = ManagerOrdersRepository(api);

    await expectLater(
      repository.assign(
        orderId: '9d5eaa73-4c17-467e-995f-2af4a428b5a1',
        companyId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        quantity: 0,
      ),
      throwsArgumentError,
    );

    expect(api.lastPostEndpoint, isNull);
  });
}
