import 'dart:io';

import 'package:flutter/services.dart';

class StaffUpdateInstaller {
  static const MethodChannel _channel = MethodChannel(
    'pharmaflow.staff/update',
  );

  Future<void> install(File apkFile) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('In-app APK installation is Android-only.');
    }

    if (!await apkFile.exists()) {
      throw StateError('Downloaded APK does not exist.');
    }

    final opened = await _channel.invokeMethod<bool>(
      'installApk',
      <String, Object?>{'path': apkFile.path},
    );

    if (opened != true) {
      throw StateError('Android installer did not open.');
    }
  }
}
