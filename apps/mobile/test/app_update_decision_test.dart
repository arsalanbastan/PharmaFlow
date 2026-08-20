import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/update/android_update_manifest.dart';
import 'package:pharmaflow/core/update/app_update_decision.dart';

void main() {
  test('disabled manifest does not offer an update', () {
    final manifest = AndroidUpdateManifest.fromJson(const {
      'enabled': false,
      'platform': 'android',
    });

    final decision = evaluateAppUpdate(
      manifest: manifest,
      currentVersionCode: 1,
    );

    expect(decision.status, AppUpdateStatus.publishingDisabled);

    expect(decision.updateAvailable, isFalse);
    expect(decision.mandatory, isFalse);
  });

  test('same version is up to date', () {
    final manifest = AndroidUpdateManifest.fromJson({
      'enabled': true,
      'platform': 'android',
      'latestVersionName': '1.0.0',
      'latestVersionCode': 1,
      'minimumSupportedVersionCode': 1,
      'mandatory': false,
      'apkUrl': 'https://example.test/app.apk',
      'sha256': 'a' * 64,
      'fileSize': 100,
      'releaseNotes': '',
      'publishedAt': null,
    });

    final decision = evaluateAppUpdate(
      manifest: manifest,
      currentVersionCode: 1,
    );

    expect(decision.status, AppUpdateStatus.upToDate);

    expect(decision.updateAvailable, isFalse);
  });

  test('higher version is available', () {
    final manifest = AndroidUpdateManifest.fromJson({
      'enabled': true,
      'platform': 'android',
      'latestVersionName': '1.0.1',
      'latestVersionCode': 2,
      'minimumSupportedVersionCode': 1,
      'mandatory': false,
      'apkUrl': 'https://example.test/app.apk',
      'sha256': 'b' * 64,
      'fileSize': 100,
      'releaseNotes': 'New release',
      'publishedAt': '2026-08-15T08:00:00.000Z',
    });

    final decision = evaluateAppUpdate(
      manifest: manifest,
      currentVersionCode: 1,
    );

    expect(decision.status, AppUpdateStatus.updateAvailable);

    expect(decision.updateAvailable, isTrue);
    expect(decision.mandatory, isFalse);
  });

  test('version below minimum supported becomes mandatory', () {
    final manifest = AndroidUpdateManifest.fromJson({
      'enabled': true,
      'platform': 'android',
      'latestVersionName': '2.0.0',
      'latestVersionCode': 5,
      'minimumSupportedVersionCode': 3,
      'mandatory': false,
      'apkUrl': 'https://example.test/app.apk',
      'sha256': 'c' * 64,
      'fileSize': 100,
      'releaseNotes': '',
      'publishedAt': null,
    });

    final decision = evaluateAppUpdate(
      manifest: manifest,
      currentVersionCode: 1,
    );

    expect(decision.updateAvailable, isTrue);
    expect(decision.mandatory, isTrue);
  });
}
