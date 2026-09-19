import 'staff_android_update_manifest.dart';

class StaffUpdateRunner {
  bool get isSupported => false;

  Future<StaffAndroidUpdateManifest> check() {
    throw UnsupportedError('APK updates are not available in the Staff PWA.');
  }

  Future<void> downloadAndInstall({
    required StaffAndroidUpdateManifest manifest,
    void Function(double progress)? onProgress,
  }) {
    throw UnsupportedError('APK updates are not available in the Staff PWA.');
  }

  void close() {}
}
