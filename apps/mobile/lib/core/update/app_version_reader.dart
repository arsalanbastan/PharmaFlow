import 'dart:io';

import 'package:flutter/services.dart';

import 'app_version_info.dart';

class AppVersionReader {
  const AppVersionReader();

  static const MethodChannel _channel = MethodChannel('pharmaflow/app_update');

  Future<AppVersionInfo> read() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'App update version reading is currently supported on Android only.',
      );
    }

    final payload = await _channel.invokeMapMethod<String, dynamic>(
      'getAppVersion',
    );

    if (payload == null) {
      throw const FormatException('Android app version response was empty.');
    }

    final versionName = payload['versionName'];
    final versionCode = payload['versionCode'];

    if (versionName is! String || versionName.trim().isEmpty) {
      throw const FormatException('Android versionName is invalid.');
    }

    if (versionCode is! int || versionCode <= 0) {
      throw const FormatException('Android versionCode is invalid.');
    }

    return AppVersionInfo(
      versionName: versionName.trim(),
      versionCode: versionCode,
    );
  }
}
