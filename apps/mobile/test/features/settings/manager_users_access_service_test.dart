import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/settings/data/manager_users_access_service.dart';

void main() {
  test('parses staff permissions from the server response', () {
    final user = ManagedAppUser.fromJson(<String, dynamic>{
      'userId': '11111111-1111-4111-8111-111111111111',
      'username': 'amir',
      'displayName': 'امیر',
      'role': 'STAFF',
      'isActive': true,
      'permissions': <String, dynamic>{
        'managerAppAccess': true,
        'canCreateOrders': true,
        'canCreateCheques': true,
        'canCreateCashPayments': false,
        'canViewFinancialReports': false,
      },
    });

    expect(user.isManager, isFalse);
    expect(user.permissions.managerAppAccess, isTrue);
    expect(user.permissions.canCreateCheques, isTrue);
    expect(user.permissions.canCreateCashPayments, isFalse);
  });

  test('manager without permission payload falls back to full access', () {
    final user = ManagedAppUser.fromJson(<String, dynamic>{
      'userId': '22222222-2222-4222-8222-222222222222',
      'username': 'manager',
      'displayName': 'مدیر',
      'role': 'MANAGER',
      'isActive': true,
    });

    expect(user.isManager, isTrue);
    expect(user.permissions.managerAppAccess, isTrue);
    expect(user.permissions.canCreateOrders, isTrue);
    expect(user.permissions.canCreateCheques, isTrue);
    expect(user.permissions.canCreateCashPayments, isTrue);
    expect(user.permissions.canViewFinancialReports, isTrue);
  });
}
