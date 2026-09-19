import 'package:shared_preferences/shared_preferences.dart';

class StaffProfileStore {
  static const String _nameKey = 'staff_display_name';

  Future<String?> loadName() async {
    final preferences = await SharedPreferences.getInstance();

    final value = preferences.getString(_nameKey)?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  Future<void> saveName(String name) async {
    final normalized = name.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Staff display name cannot be empty.');
    }

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_nameKey, normalized);
  }
}
