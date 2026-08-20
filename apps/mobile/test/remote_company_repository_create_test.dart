import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test(
    'createWithClientUuid sends the exact client UUID and returns server UUID',
    () async {
      const uuid = '12345678-1234-4234-8234-123456789abc';

      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount += 1;

        expect(request.method, equals('POST'));

        expect(request.url.path, contains('/companies'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['id'], equals(uuid));

        expect(body['name'], equals('Remote Create Test'));

        return http.Response(
          jsonEncode(<String, dynamic>{
            'id': uuid,
            'name': 'Remote Create Test',
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });

      final repository = RemoteCompanyRepository(ApiClient(httpClient: client));

      final returnedUuid = await repository
          .createWithClientUuid(<String, dynamic>{
            'id': uuid,
            'name': 'Remote Create Test',
            'nationalId': null,
            'economicCode': null,
            'notes': null,
            'visitorName': null,
            'visitorPhone': null,
            'accountantName': null,
            'accountantPhone': null,
            'archivedAt': null,
          });

      expect(returnedUuid, equals(uuid));

      expect(requestCount, equals(1));
    },
  );

  test('retrying createWithClientUuid reuses the same client UUID', () async {
    const uuid = '22345678-1234-4234-8234-123456789abc';

    final requestedIds = <String>[];

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      requestedIds.add(body['id'] as String);

      return http.Response(
        jsonEncode(<String, dynamic>{'id': uuid, 'name': body['name']}),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final repository = RemoteCompanyRepository(ApiClient(httpClient: client));

    final firstPayload = <String, dynamic>{
      'id': uuid,
      'name': 'First Snapshot',
    };

    final retryPayload = <String, dynamic>{
      'id': uuid,
      'name': 'Latest Snapshot',
    };

    expect(await repository.createWithClientUuid(firstPayload), equals(uuid));

    expect(await repository.createWithClientUuid(retryPayload), equals(uuid));

    expect(requestedIds, equals(<String>[uuid, uuid]));
  });

  test(
    'createWithClientUuid rejects payload without client UUID before network call',
    () async {
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount += 1;

        return http.Response('{}', 200);
      });

      final repository = RemoteCompanyRepository(ApiClient(httpClient: client));

      await expectLater(
        repository.createWithClientUuid(<String, dynamic>{
          'name': 'Missing UUID',
        }),
        throwsA(isA<ArgumentError>()),
      );

      expect(requestCount, equals(0));
    },
  );

  test('createWithClientUuid rejects response without a server UUID', () async {
    const uuid = '32345678-1234-4234-8234-123456789abc';

    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{'name': 'Missing Response UUID'}),
        201,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final repository = RemoteCompanyRepository(ApiClient(httpClient: client));

    await expectLater(
      repository.createWithClientUuid(<String, dynamic>{
        'id': uuid,
        'name': 'Missing Response UUID',
      }),
      throwsA(isA<ApiDecodingException>()),
    );
  });
}
