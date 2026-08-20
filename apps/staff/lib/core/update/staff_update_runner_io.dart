import 'dart:io';

import 'staff_android_update_manifest.dart';
import 'staff_update_downloader.dart';
import 'staff_update_installer.dart';
import 'staff_update_service.dart';

class StaffUpdateRunner {
  StaffUpdateRunner({StaffUpdateService? service})
    : _service = service ?? StaffUpdateService();

  final StaffUpdateService _service;

  bool get isSupported => Platform.isAndroid;

  Future<StaffAndroidUpdateManifest> check() {
    if (!isSupported) {
      throw UnsupportedError('In-app APK update is Android-only.');
    }

    return _service.check();
  }

  Future<void> downloadAndInstall({
    required StaffAndroidUpdateManifest manifest,
    void Function(double progress)? onProgress,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('In-app APK update is Android-only.');
    }

    final apkUrl = manifest.apkUrl;
    final expectedSize = manifest.fileSize;
    final expectedSha = manifest.sha256;
    final versionCode = manifest.latestVersionCode;

    if (apkUrl == null ||
        expectedSize == null ||
        expectedSha == null ||
        versionCode == null) {
      throw const FormatException('Update manifest is incomplete.');
    }

    final download = await StaffUpdateDownloader().download(
      url: Uri.parse(apkUrl),
      expectedSize: expectedSize,
      expectedSha256: expectedSha,
      versionCode: versionCode,
      onProgress: onProgress,
    );

    await StaffUpdateInstaller().install(download.file);
  }

  void close() {
    _service.close();
  }
}
