import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';
import 'auth_token_storage.dart';

final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return AuthTokenStorage();
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authTokenStorageProvider))..load();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._storage) : super(const AuthState.unauthenticated());

  final AuthTokenStorage _storage;

  Future<void> load() async {
    state = (await _storage.hasToken())
        ? const AuthState.authenticated()
        : const AuthState.unauthenticated();
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> signOut() async {
    await _storage.deleteToken();
    state = const AuthState.unauthenticated();
  }
}
