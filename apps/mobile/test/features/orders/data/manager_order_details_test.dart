import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/features/orders/data/manager_orders_repository.dart';

class _FakeApiClient extends ApiClient {
  final Map<String, dynamic> responses = <String, dynamic>{};
  final List<String> getEndpoints = <String>[];

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    getEndpoints.add(endpoint);

    if (!responses.containsKey(endpoint)) {
      throw StateError('No fake response for $endpoint');
    }

    return responses[endpoint];
  }
}

void main() {
  const orderId = '9d5eaa73-4c17-467e-995f-2af4a428b5a1';

  test('getById parses the full manager order detail contract', () async {
    final api = _FakeApiClient();
    api.responses['/orders/$orderId'] = <String, dynamic>{
      'id': orderId,
      'category': 'DRUG',
      'itemText': 'آتورواستاتین 20 تست',
      'requestedQuantity': 2,
      'orderedQuantity': 3,
      'suggestedCompanyText': 'هجرت',
      'notes': 'یادداشت تست',
      'status': 'ORDERED',
      'possibleDuplicate': true,
      'requestedByName': 'ارسلان2',
      'requestedByUserId': '11111111-1111-4111-8111-111111111111',
      'orderedByName': 'ارسلان',
      'orderedByUserId': '22222222-2222-4222-8222-222222222222',
      'receivedByName': null,
      'canceledByName': null,
      'deletedByName': null,
      'createdAt': '2026-08-18T04:00:00.000Z',
      'updatedAt': '2026-08-18T05:00:00.000Z',
      'orderedAt': '2026-08-18T05:00:00.000Z',
      'receivedAt': null,
      'canceledAt': null,
      'deletedAt': null,
      'photoStorageKey': null,
      'photoFileSize': null,
      'photoSha256': null,
      'photoDeletedAt': '2026-08-18T05:01:00.000Z',
      'assignedCompany': <String, dynamic>{
        'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'name': 'داروپخش',
      },
    };

    final repository = ManagerOrdersRepository(api);
    final details = await repository.getById(orderId);

    expect(details.id, orderId);
    expect(details.itemText, 'آتورواستاتین 20 تست');
    expect(details.requestedQuantity, 2);
    expect(details.orderedQuantity, 3);
    expect(details.requestedByName, 'ارسلان2');
    expect(details.orderedByName, 'ارسلان');
    expect(details.assignedCompanyName, 'داروپخش');
    expect(details.possibleDuplicate, isTrue);
    expect(details.photoWasDeleted, isTrue);
    expect(details.orderedAt, isNotNull);
    expect(api.getEndpoints, <String>['/orders/$orderId']);
  });

  test('getPhoto parses lazy presigned photo response', () async {
    final api = _FakeApiClient();
    api.responses['/orders/$orderId/photo'] = <String, dynamic>{
      'orderId': orderId,
      'fileSize': 123456,
      'sha256': 'a' * 64,
      'downloadUrl': 'https://example.test/presigned-photo',
      'expiresInSeconds': 300,
    };

    final repository = ManagerOrdersRepository(api);
    final photo = await repository.getPhoto(orderId);

    expect(photo, isNotNull);
    expect(photo!.orderId, orderId);
    expect(photo.fileSize, 123456);
    expect(photo.downloadUrl, 'https://example.test/presigned-photo');
    expect(photo.expiresInSeconds, 300);
    expect(api.getEndpoints, <String>['/orders/$orderId/photo']);
  });

  test(
    'details endpoints reject blank order id before network access',
    () async {
      final api = _FakeApiClient();
      final repository = ManagerOrdersRepository(api);

      expect(() => repository.getById('   '), throwsArgumentError);
      expect(() => repository.getPhoto('   '), throwsArgumentError);
      expect(api.getEndpoints, isEmpty);
    },
  );
}
