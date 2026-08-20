import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/core/auth/staff_auth_session.dart';
import 'package:pharmaflow_staff/core/auth/staff_login_page.dart';
import 'package:pharmaflow_staff/core/update/staff_update_runner.dart';
import 'package:pharmaflow_staff/main.dart';

void main() {
  test('Staff application remains constructible for the web compiler', () {
    expect(const PharmaFlowStaffApp(), isA<Widget>());
  });

  testWidgets('PWA login surface keeps the Staff-only identity', (
    WidgetTester tester,
  ) async {
    StaffAuthSession? authenticatedSession;

    await tester.pumpWidget(
      MaterialApp(
        home: StaffLoginPage(
          onAuthenticated: (session) {
            authenticatedSession = session;
          },
        ),
      ),
    );

    expect(find.text('PharmaFlow Staff'), findsOneWidget);
    expect(find.text('نام کاربری'), findsOneWidget);
    expect(find.text('رمز عبور'), findsOneWidget);
    expect(find.textContaining('مدیریت مالی'), findsNothing);
    expect(authenticatedSession, isNull);
  });

  test('APK update flow is unavailable outside Android', () {
    expect(StaffUpdateRunner().isSupported, isFalse);
  });
}
