import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/core/update/staff_android_update_manifest.dart';

void main() {
  test('disabled manifest never offers an update', () {
    const manifest = StaffAndroidUpdateManifest(
      enabled: false,
      platform: 'android',
    );

    expect(manifest.updateAvailableFor(1), isFalse);
  });

  test('higher versionCode offers update', () {
    const manifest = StaffAndroidUpdateManifest(
      enabled: true,
      platform: 'android',
      latestVersionName: '0.0.2',
      latestVersionCode: 2,
      minimumSupportedVersionCode: 1,
      mandatory: false,
      apkUrl: 'https://example.com/app.apk',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      fileSize: 100,
    );

    expect(manifest.updateAvailableFor(1), isTrue);

    expect(manifest.isMandatoryFor(1), isFalse);
  });

  test('minimum supported version makes update mandatory', () {
    const manifest = StaffAndroidUpdateManifest(
      enabled: true,
      platform: 'android',
      latestVersionName: '0.0.3',
      latestVersionCode: 3,
      minimumSupportedVersionCode: 2,
      mandatory: false,
      apkUrl: 'https://example.com/app.apk',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      fileSize: 100,
    );

    expect(manifest.isMandatoryFor(1), isTrue);
  });
}
