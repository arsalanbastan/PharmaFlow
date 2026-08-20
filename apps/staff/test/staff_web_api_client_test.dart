import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmaflow_staff/core/auth/staff_auth_token_storage.dart';
import 'package:pharmaflow_staff/features/orders/data/staff_order_api_service.dart';

class _TokenStorage extends StaffAuthTokenStorage {
  @override
  Future<String?> readToken() async => 'test-session-token-1234567890';
}

void main() {
  test(
    'web photo upload stays authenticated and uses the backend gateway',
    () async {
      final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
      late http.Request captured;

      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = StaffOrderApiService(
        httpClient: client,
        authStorage: _TokenStorage(),
      );

      await service.uploadWebPhoto(
        orderId: '11111111-1111-4111-8111-111111111111',
        bytes: bytes,
        sha256: List.filled(64, 'a').join(),
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, contains('/photo/upload-web'));
      expect(captured.headers['Authorization'], startsWith('Bearer '));

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['mimeType'], 'image/jpeg');
      expect(body['fileSize'], bytes.length);
      expect(base64Decode(body['imageBase64'] as String), bytes);

      service.close();
    },
  );

  test('pending edit and delete use authenticated requester routes', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);

      if (request.method == 'DELETE') {
        return http.Response('{}', 200);
      }

      return http.Response(
        jsonEncode({
          'id': 'pending-order',
          'category': 'GOODS',
          'itemText': 'شامپو ویرایش‌شده',
          'status': 'PENDING',
          'requestedByName': 'مریم',
          'requestedByUserId': '11111111-1111-4111-8111-111111111111',
          'createdAt': '2026-08-20T00:00:00.000Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = StaffOrderApiService(
      httpClient: client,
      authStorage: _TokenStorage(),
    );

    final updated = await service.updatePendingOrder(
      orderId: 'pending-order',
      category: 'GOODS',
      itemText: 'شامپو ویرایش‌شده',
      requestedQuantity: 3,
    );
    await service.deletePendingOrder(orderId: 'pending-order');

    expect(updated.itemText, 'شامپو ویرایش‌شده');
    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, endsWith('/orders/pending-order/edit'));
    expect(requests[1].method, 'DELETE');
    expect(requests[1].url.path, endsWith('/orders/pending-order'));
    expect(
      requests.every(
        (request) =>
            request.headers['Authorization']?.startsWith('Bearer ') ?? false,
      ),
      isTrue,
    );

    service.close();
  });
}
