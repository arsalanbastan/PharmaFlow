import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmaflow/core/update/app_update_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('pharmaflow/app_update');

  final calls = <MethodCall>[];

  setUp(() async {
    calls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);

          switch (call.method) {
            case 'canRequestPackageInstalls':
              return true;

            case 'openInstallPermissionSettings':
              return null;

            case 'installApk':
              return null;
          }

          throw PlatformException(code: 'UNEXPECTED_METHOD');
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads install permission state', () async {
    const installer = AppUpdateInstaller();

    expect(await installer.canRequestPackageInstalls(), isTrue);

    expect(calls.single.method, 'canRequestPackageInstalls');
  });

  test('opens Android install permission settings', () async {
    const installer = AppUpdateInstaller();

    await installer.openInstallPermissionSettings();

    expect(calls.single.method, 'openInstallPermissionSettings');
  });

  test('passes verified APK path to native installer', () async {
    const installer = AppUpdateInstaller();

    await installer.installVerifiedApk(r'C:\test\pharmaflow-2.apk');

    expect(calls.single.method, 'installApk');

    expect(calls.single.arguments, <String, Object>{
      'filePath': r'C:\test\pharmaflow-2.apk',
    });
  });

  test('rejects an empty verified APK path', () async {
    const installer = AppUpdateInstaller();

    await expectLater(
      installer.installVerifiedApk('   '),
      throwsA(isA<AppUpdateInstallException>()),
    );

    expect(calls, isEmpty);
  });
}
