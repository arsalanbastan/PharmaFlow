import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'connection_profile.dart';

class ConnectionSettingsRepository {
  ConnectionSettingsRepository({Future<SharedPreferences>? sharedPreferences})
    : _sharedPreferences = sharedPreferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _sharedPreferences;

  static const String _settingsKey = 'connection_settings_v1';
  static const String _autoSyncUpgradeKey =
      'connection_settings_auto_sync_upgrade_v1';

  Future<ConnectionSettings> load() async {
    final preferences = await _sharedPreferences;
    final rawValue = preferences.getString(_settingsKey);

    ConnectionSettings settings = ConnectionSettingsDefaults.defaultSettings;

    if (rawValue != null && rawValue.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValue);

        if (decoded is Map<String, dynamic>) {
          settings = ConnectionSettings.fromJson(decoded);
        }
      } on FormatException {
        // Reset to defaults when persisted JSON is invalid.
      }
    }

    if (preferences.getBool(_autoSyncUpgradeKey) == true) {
      return settings;
    }

    // Existing installations inherited Auto Sync=false from the historical
    // default. Enable it once on upgrade so app start and every queued local
    // mutation are synchronized immediately. The user can still disable the
    // setting afterwards; the marker prevents a later load from overriding it.
    final upgraded = settings.copyWith(
      autoSync: true,
      consecutiveConnectionFailures: 0,
      autoRetrySuspended: false,
      clearLastSyncUserSafeErrorMessage: true,
    );

    await preferences.setString(_settingsKey, jsonEncode(upgraded.toJson()));
    await preferences.setBool(_autoSyncUpgradeKey, true);

    return upgraded;
  }

  Future<void> save(ConnectionSettings settings) async {
    final preferences = await _sharedPreferences;
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
    await preferences.setBool(_autoSyncUpgradeKey, true);
  }
}
