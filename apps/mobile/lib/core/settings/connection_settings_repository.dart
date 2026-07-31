import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'connection_profile.dart';

class ConnectionSettingsRepository {
  ConnectionSettingsRepository({Future<SharedPreferences>? sharedPreferences})
    : _sharedPreferences = sharedPreferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _sharedPreferences;

  static const String _settingsKey = 'connection_settings_v1';

  Future<ConnectionSettings> load() async {
    final preferences = await _sharedPreferences;
    final rawValue = preferences.getString(_settingsKey);

    if (rawValue == null || rawValue.trim().isEmpty) {
      return ConnectionSettingsDefaults.defaultSettings;
    }

    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is Map<String, dynamic>) {
        return ConnectionSettings.fromJson(decoded);
      }
    } on FormatException {
      // Reset to defaults when persisted JSON is invalid.
    }

    return ConnectionSettingsDefaults.defaultSettings;
  }

  Future<void> save(ConnectionSettings settings) async {
    final preferences = await _sharedPreferences;
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
