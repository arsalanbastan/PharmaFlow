import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pharmaflow/core/config/app_config.dart';
import 'package:pharmaflow/core/config/app_environment.dart';
import 'package:pharmaflow/core/settings/connection_profile.dart';
import 'package:pharmaflow/core/settings/connection_settings_repository.dart';

void main() {
  test('default profile uses Liara production values and autoSync is true', () {
    final profile = ConnectionSettingsDefaults.defaultProfile;
    final settings = ConnectionSettingsDefaults.defaultSettings;

    expect(profile.id, equals('default'));
    expect(profile.name, equals('Liara Production'));
    expect(profile.host, equals('naughty-haslett-zvtszb2yr.liara.run'));
    expect(profile.port, equals(443));
    expect(profile.useHttps, isTrue);
    expect(profile.apiVersion, equals('v1'));
    expect(profile.connectTimeout, equals(15000));
    expect(profile.receiveTimeout, equals(15000));
    expect(settings.autoSync, isTrue);
  });

  test('AppConfig baseUrl builds expected production URL', () {
    final config = AppConfig(
      currentEnvironment: AppEnvironment.development,
      settings: ConnectionSettingsDefaults.defaultSettings,
    );

    expect(
      config.baseUrl,
      equals('https://naughty-haslett-zvtszb2yr.liara.run:443/api/v1'),
    );
  });

  test(
    'one-time upgrade enables auto sync for an existing installation',
    () async {
      final oldSettings = ConnectionSettingsDefaults.defaultSettings.copyWith(
        autoSync: false,
      );

      SharedPreferences.setMockInitialValues(<String, Object>{
        'connection_settings_v1': jsonEncode(oldSettings.toJson()),
      });

      final repository = ConnectionSettingsRepository();
      final upgraded = await repository.load();

      expect(upgraded.autoSync, isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool('connection_settings_auto_sync_upgrade_v1'),
        isTrue,
      );
    },
  );

  test('an explicit user save can still keep auto sync disabled', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final repository = ConnectionSettingsRepository();
    final disabled = ConnectionSettingsDefaults.defaultSettings.copyWith(
      autoSync: false,
    );

    await repository.save(disabled);

    final restored = await repository.load();
    expect(restored.autoSync, isFalse);
  });
}
