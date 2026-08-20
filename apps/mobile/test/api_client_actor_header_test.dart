import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pharmaflow/core/auth/auth_token_storage.dart';
import 'package:pharmaflow/core/network/api_client.dart';

class _FakeAuthTokenStorage extends AuthTokenStorage {
  @override
  Future<String?> getToken() async => null;
}

String _encodedActor(String value) {
  return 'utf8b64:${base64Encode(utf8.encode(value))}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'POST PATCH DELETE send latest UTF-8 safe actor while GET does not',
    () async {
      final requests = <http.Request>[];

      final client = MockClient((request) async {
        requests.add(request);

        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      var displayName = 'کاربر اول';

      final api = ApiClient(
        httpClient: client,
        authTokenStorage: _FakeAuthTokenStorage(),
        actorDisplayNameProvider: () async => displayName,
      );

      await api.get('/companies');
      await api.post('/companies', body: {'name': 'Test'});

      displayName = 'کاربر دوم';

      await api.patch('/companies/test-id', body: {'name': 'Updated'});
      await api.delete('/companies/test-id');

      expect(requests, hasLength(4));

      expect(requests[0].headers['x-pharmaflow-actor-name'], isNull);

      expect(
        requests[1].headers['x-pharmaflow-actor-name'],
        _encodedActor('کاربر اول'),
      );

      expect(
        requests[2].headers['x-pharmaflow-actor-name'],
        _encodedActor('کاربر دوم'),
      );

      expect(
        requests[3].headers['x-pharmaflow-actor-name'],
        _encodedActor('کاربر دوم'),
      );

      for (final request in requests.skip(1)) {
        final actorHeader = request.headers['x-pharmaflow-actor-name'];

        expect(actorHeader, isNotNull);

        expect(
          actorHeader!.codeUnits.every((unit) => unit <= 0x7f),
          isTrue,
          reason: 'Actor HTTP header must contain ASCII only.',
        );
      }
    },
  );

  test('actor lookup failure does not block mutation', () async {
    final client = MockClient((request) async {
      return http.Response('{}', 200);
    });

    final api = ApiClient(
      httpClient: client,
      authTokenStorage: _FakeAuthTokenStorage(),
      actorDisplayNameProvider: () async {
        throw StateError('settings unavailable');
      },
    );

    await expectLater(
      api.post('/companies', body: {'name': 'Still sent'}),
      completes,
    );
  });
}
