import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/core/auth/staff_auth_user.dart';

void main() {
  test('parses a valid STAFF user payload', () {
    final user = StaffAuthUser.fromJson({
      'userId': '11111111-1111-4111-8111-111111111111',
      'username': 'arsalan2',
      'displayName': 'ارسلان 2',
      'role': 'STAFF',
      'isActive': true,
    });

    expect(user.username, 'arsalan2');

    expect(user.displayName, 'ارسلان 2');

    expect(user.isStaff, isTrue);
  });

  test('rejects incomplete user payload', () {
    expect(
      () => StaffAuthUser.fromJson({'username': 'arsalan2'}),
      throwsFormatException,
    );
  });
}
