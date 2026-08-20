import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/core/navigation/staff_back_navigation_scope.dart';

void main() {
  testWidgets('back from request page returns to home first', (tester) async {
    var isHome = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return StaffBackNavigationScope(
              isHome: isHome,
              onReturnHome: () {
                setState(() {
                  isHome = true;
                });
              },
              child: Scaffold(body: Text(isHome ? 'خانه' : 'ثبت درخواست')),
            );
          },
        ),
      ),
    );

    expect(find.text('ثبت درخواست'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('خانه'), findsOneWidget);
    final popScope = tester.widget<PopScope<Object?>>(
      find.byKey(const ValueKey('staff-back-navigation-pop-scope')),
    );
    expect(popScope.canPop, isTrue);
  });
}
