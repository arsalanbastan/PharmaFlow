import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStorage {
  AuthTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'auth_token_v1';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token.trim());
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);

    if (token == null) {
      return null;
    }

    final normalized = token.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    return (await getToken()) != null;
  }
}
