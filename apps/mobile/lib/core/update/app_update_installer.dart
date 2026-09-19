import 'package:flutter/services.dart';

class AppUpdateInstallException implements Exception {
  const AppUpdateInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUpdateInstaller {
  const AppUpdateInstaller();

  static const MethodChannel _channel = MethodChannel('pharmaflow/app_update');

  Future<bool> canRequestPackageInstalls() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          false;
    } on PlatformException catch (error) {
      throw AppUpdateInstallException(
        error.message ?? 'Unable to check Android installation permission.',
      );
    }
  }

  Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } on PlatformException catch (error) {
      throw AppUpdateInstallException(
        error.message ?? 'Unable to open Android installation settings.',
      );
    }
  }

  Future<void> installVerifiedApk(String filePath) async {
    final normalizedPath = filePath.trim();

    if (normalizedPath.isEmpty) {
      throw const AppUpdateInstallException('Verified APK path is empty.');
    }

    try {
      await _channel.invokeMethod<void>('installApk', <String, Object>{
        'filePath': normalizedPath,
      });
    } on PlatformException catch (error) {
      throw AppUpdateInstallException(
        error.message ?? 'Unable to start Android package installation.',
      );
    }
  }
}
