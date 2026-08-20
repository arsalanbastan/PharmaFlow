import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pharmaflow/core/auth/auth_token_storage.dart';

import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/data/models/cash_payment_attachment.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cash_payment_attachment_repository.dart';

class _FakeAuthTokenStorage extends AuthTokenStorage {
  @override
  Future<String?> getToken() async => null;
}

void main() {
  const paymentUuid = '11111111-1111-4111-8111-111111111111';

  const attachmentUuid = '22222222-2222-4222-8222-222222222222';

  const storageKey =
      'cash-payments/'
      '$paymentUuid/'
      '$attachmentUuid.pdf';

  const uploadUrl =
      'https://storage.test/$storageKey'
      '?X-Amz-Signature=test';

  final metadata = CashPaymentAttachmentUploadMetadata(
    id: attachmentUuid,
    cashPaymentId: paymentUuid,
    kind: CashPaymentAttachmentKind.statement,
    fileName: 'statement.pdf',
    mimeType: 'application/pdf',
    originalFileSize: 351,
    fileSize: 351,
    sha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );

  Map<String, dynamic> recordJson({String? deletedAt}) {
    return <String, dynamic>{
      'id': attachmentUuid,
      'cashPaymentId': paymentUuid,
      'kind': 'STATEMENT',
      'fileName': 'statement.pdf',
      'mimeType': 'application/pdf',
      'originalFileSize': 351,
      'fileSize': 351,
      'sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'storageKey': storageKey,
      'deletedAt': deletedAt,
      'createdAt': '2026-08-16T10:00:00.000Z',
      'updatedAt': '2026-08-16T10:01:00.000Z',
    };
  }

  test('prepare PUT confirm follows backend attachment contract', () async {
    var prepareCalled = false;
    var confirmCalled = false;
    var putCalled = false;

    final apiHttpClient = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith(
            '/cash-payment-attachments/prepare-upload',
          )) {
        prepareCalled = true;

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['id'], attachmentUuid);

        expect(body['cashPaymentId'], paymentUuid);

        expect(body['kind'], 'STATEMENT');

        expect(body['fileSize'], 351);

        return http.Response(
          jsonEncode(<String, dynamic>{
            'attachmentId': attachmentUuid,
            'storageKey': storageKey,
            'uploadUrl': uploadUrl,
            'expiresInSeconds': 1800,
          }),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.method == 'POST' &&
          request.url.path.endsWith('/cash-payment-attachments/confirm')) {
        confirmCalled = true;

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['id'], attachmentUuid);

        return http.Response(
          jsonEncode(recordJson()),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response('not found', 404);
    });

    final uploadHttpClient = MockClient((request) async {
      expect(request.method, 'PUT');

      expect(request.url.toString(), uploadUrl);

      expect(request.headers['content-type'], 'application/pdf');

      expect(request.bodyBytes, Uint8List.fromList(<int>[1, 2, 3, 4]));

      putCalled = true;

      return http.Response('', 200);
    });

    final repository = RemoteCashPaymentAttachmentRepository(
      ApiClient(
        httpClient: apiHttpClient,
        authTokenStorage: _FakeAuthTokenStorage(),
      ),
      uploadClient: uploadHttpClient,
    );

    final prepared = await repository.prepareUpload(metadata);

    expect(prepared.attachmentId, attachmentUuid);

    expect(prepared.storageKey, storageKey);

    expect(prepared.uploadUrl, uploadUrl);

    await repository.uploadBytes(
      uploadUrl: prepared.uploadUrl,
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      mimeType: 'application/pdf',
    );

    final confirmed = await repository.confirm(metadata);

    expect(confirmed.id, attachmentUuid);

    expect(confirmed.storageKey, storageKey);

    expect(confirmed.kind, CashPaymentAttachmentKind.statement);

    expect(prepareCalled, isTrue);
    expect(putCalled, isTrue);
    expect(confirmCalled, isTrue);
  });

  test('list changes download and delete contracts decode correctly', () async {
    var listCalled = false;
    var changesCalled = false;
    var downloadCalled = false;
    var deleteCalled = false;

    final apiHttpClient = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/cash-payment-attachments')) {
        listCalled = true;

        expect(request.url.queryParameters['cashPaymentId'], paymentUuid);

        return http.Response(
          jsonEncode(<Map<String, dynamic>>[recordJson()]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.method == 'GET' &&
          request.url.path.endsWith('/cash-payment-attachments/changes')) {
        changesCalled = true;

        expect(request.url.queryParameters['limit'], '50');

        expect(request.url.queryParameters['afterId'], attachmentUuid);

        return http.Response(
          jsonEncode(<String, dynamic>{
            'items': <Map<String, dynamic>>[recordJson()],
            'hasMore': false,
            'nextCursor': <String, dynamic>{
              'updatedAt': '2026-08-16T10:01:00.000Z',
              'id': attachmentUuid,
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.method == 'GET' &&
          request.url.path.endsWith(
            '/cash-payment-attachments/'
            '$attachmentUuid/download-url',
          )) {
        downloadCalled = true;

        return http.Response(
          jsonEncode(<String, dynamic>{
            'attachment': recordJson(),
            'downloadUrl':
                'https://storage.test/download.pdf'
                '?X-Amz-Signature=test',
            'expiresInSeconds': 1800,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.method == 'DELETE' &&
          request.url.path.endsWith(
            '/cash-payment-attachments/'
            '$attachmentUuid',
          )) {
        deleteCalled = true;

        return http.Response('', 200);
      }

      return http.Response('not found', 404);
    });

    final repository = RemoteCashPaymentAttachmentRepository(
      ApiClient(
        httpClient: apiHttpClient,
        authTokenStorage: _FakeAuthTokenStorage(),
      ),
      uploadClient: MockClient((_) async => http.Response('', 200)),
    );

    final list = await repository.getAll(cashPaymentId: paymentUuid);

    expect(list, hasLength(1));
    expect(list.single.id, attachmentUuid);

    final cursor = SyncCursor(
      entityType: syncEntityTypeCashPaymentAttachment,
      updatedAt: DateTime.parse('2026-08-16T10:00:00.000Z'),
      serverUuid: attachmentUuid,
    );

    final changes = await repository.getChanges(cursor: cursor, limit: 50);

    expect(changes.items, hasLength(1));

    expect(changes.nextCursor?.serverUuid, attachmentUuid);

    final download = await repository.getDownloadInfo(attachmentUuid);

    expect(download.attachment.id, attachmentUuid);

    expect(download.downloadUrl, contains('X-Amz-Signature'));

    await repository.delete(attachmentUuid);

    expect(listCalled, isTrue);
    expect(changesCalled, isTrue);
    expect(downloadCalled, isTrue);
    expect(deleteCalled, isTrue);
  });

  test('invalid changes cursor entity type is rejected locally', () async {
    final repository = RemoteCashPaymentAttachmentRepository(
      ApiClient(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        authTokenStorage: _FakeAuthTokenStorage(),
      ),
      uploadClient: MockClient((_) async => http.Response('', 200)),
    );

    final cursor = SyncCursor(
      entityType: syncEntityTypeCashPayment,
      updatedAt: DateTime.now().toUtc(),
      serverUuid: attachmentUuid,
    );

    expect(() => repository.getChanges(cursor: cursor), throwsArgumentError);
  });
}
