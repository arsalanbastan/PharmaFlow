import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'staff_auth_session.dart';
import 'staff_auth_user.dart';

class StaffAuthTokenStorage {
  StaffAuthTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'staff_auth_token_v1';
  static const String _userKey = 'staff_auth_user_v1';
  static const String _expiresAtKey = 'staff_auth_expires_at_v1';

  Future<void> save(StaffAuthSession session) async {
    final token = session.token.trim();

    if (token.isEmpty) {
      throw ArgumentError('Authentication token cannot be empty.');
    }

    await _storage.write(key: _tokenKey, value: token);

    await _storage.write(
      key: _userKey,
      value: jsonEncode(session.user.toJson()),
    );

    final expiresAt = session.expiresAt;

    if (expiresAt == null) {
      await _storage.delete(key: _expiresAtKey);
    } else {
      await _storage.write(
        key: _expiresAtKey,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  Future<StaffAuthSession?> load() async {
    final token = (await _storage.read(key: _tokenKey))?.trim();

    final userJson = (await _storage.read(key: _userKey))?.trim();

    if (token == null ||
        token.isEmpty ||
        userJson == null ||
        userJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(userJson);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final expiresRaw = (await _storage.read(key: _expiresAtKey))?.trim();

      final expiresAt = expiresRaw == null || expiresRaw.isEmpty
          ? null
          : DateTime.tryParse(expiresRaw);

      return StaffAuthSession(
        token: token,
        user: StaffAuthUser.fromJson(decoded),
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> readToken() async {
    final token = (await _storage.read(key: _tokenKey))?.trim();

    if (token == null || token.isEmpty) {
      return null;
    }

    return token;
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);

    await _storage.delete(key: _userKey);

    await _storage.delete(key: _expiresAtKey);
  }
}
