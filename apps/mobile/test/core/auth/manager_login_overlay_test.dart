import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/auth/manager_app_auth_gate.dart';

void main() {
  testWidgets(
    'login rendered from MaterialApp.builder has an Overlay for tooltips',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ManagerLoginOverlayHost(
            working: false,
            error: null,
            onLogin: ({required username, required password}) async => false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
