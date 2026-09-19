import 'staff_auth_user.dart';

class StaffAuthSession {
  const StaffAuthSession({
    required this.token,
    required this.user,
    this.expiresAt,
  });

  final String token;
  final StaffAuthUser user;
  final DateTime? expiresAt;
}
