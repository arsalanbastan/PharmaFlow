import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/network/api_constants.dart';
import 'package:pharmaflow/core/notifications/manager_push_device_registration_service.dart';

class _RecordedPost {
  const _RecordedPost({required this.endpoint, required this.body});

  final String endpoint;
  final Object? body;
}

class _RecordingApiClient extends ApiClient {
  final List<_RecordedPost> posts = <_RecordedPost>[];

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
  }) async {
    posts.add(_RecordedPost(endpoint: endpoint, body: body));
    return <String, dynamic>{'ok': true};
  }
}

void main() {
  group('ManagerPushDeviceRegistrationService', () {
    test(
      'registerCurrentToken sends the expected authenticated device payload',
      () async {
        final apiClient = _RecordingApiClient();
        final service = ManagerPushDeviceRegistrationService(
          apiClient: apiClient,
          fcmTokenProvider: () async => '  fcm-token-1234567890  ',
          installationIdProvider: () async => 'install-12345678',
          appPackageOverride: 'com.example.pharmaflow.dev',
        );

        final registered = await service.registerCurrentToken();

        expect(registered, isTrue);
        expect(apiClient.posts, hasLength(1));
        expect(
          apiClient.posts.single.endpoint,
          ApiConstants.pushDeviceRegisterEndpoint,
        );
        expect(apiClient.posts.single.body, <String, dynamic>{
          'token': 'fcm-token-1234567890',
          'installationId': 'install-12345678',
          'platform': 'android',
          'appPackage': 'com.example.pharmaflow.dev',
        });
      },
    );

    test('blank FCM token is ignored without an API call', () async {
      final apiClient = _RecordingApiClient();
      final service = ManagerPushDeviceRegistrationService(
        apiClient: apiClient,
        fcmTokenProvider: () async => '   ',
        installationIdProvider: () async => 'install-12345678',
        appPackageOverride: 'com.example.pharmaflow.dev',
      );

      final registered = await service.registerCurrentToken();

      expect(registered, isFalse);
      expect(apiClient.posts, isEmpty);
    });

    test(
      'unregister sends installation identity without exposing FCM token',
      () async {
        final apiClient = _RecordingApiClient();
        final service = ManagerPushDeviceRegistrationService(
          apiClient: apiClient,
          fcmTokenProvider: () async => 'unused-token',
          installationIdProvider: () async => 'install-12345678',
          appPackageOverride: 'com.example.pharmaflow.dev',
        );

        final unregistered = await service.unregister();

        expect(unregistered, isTrue);
        expect(apiClient.posts, hasLength(1));
        expect(
          apiClient.posts.single.endpoint,
          ApiConstants.pushDeviceUnregisterEndpoint,
        );
        expect(apiClient.posts.single.body, <String, dynamic>{
          'installationId': 'install-12345678',
          'appPackage': 'com.example.pharmaflow.dev',
        });
        expect(
          (apiClient.posts.single.body! as Map<String, dynamic>).containsKey(
            'token',
          ),
          isFalse,
        );
      },
    );
  });
}
