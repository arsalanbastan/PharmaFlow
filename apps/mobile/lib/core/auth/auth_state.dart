enum AuthStatus { authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status});

  const AuthState.authenticated() : status = AuthStatus.authenticated;

  const AuthState.unauthenticated() : status = AuthStatus.unauthenticated;

  final AuthStatus status;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}
