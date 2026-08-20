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
  test('manager pending edit posts the complete editable payload', () async {
    final api = _FakeApiClient();
    final repository = ManagerOrdersRepository(api);

    await repository.updatePending(
      orderId: '33333333-3333-4333-8333-333333333333',
      category: 'GOODS',
      itemText: ' شامپو تست ',
      requestedQuantity: 4,
      suggestedCompanyText: ' شرکت تست ',
      notes: ' یادداشت ',
    );

    expect(
      api.lastPostEndpoint,
      '/orders/33333333-3333-4333-8333-333333333333/edit',
    );

    expect(api.lastPostBody, <String, dynamic>{
      'category': 'GOODS',
      'itemText': 'شامپو تست',
      'requestedQuantity': 4,
      'suggestedCompanyText': 'شرکت تست',
      'notes': 'یادداشت',
    });
  });

  test('manager cancel posts to the existing cancel endpoint', () async {
    final api = _FakeApiClient();
    final repository = ManagerOrdersRepository(api);

    await repository.cancel(orderId: '33333333-3333-4333-8333-333333333333');

    expect(
      api.lastPostEndpoint,
      '/orders/33333333-3333-4333-8333-333333333333/cancel',
    );
    expect(api.lastPostBody, isNull);
  });
}
