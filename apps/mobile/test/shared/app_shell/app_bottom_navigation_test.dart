import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/shared/app_shell/app_bottom_navigation.dart';

void main() {
  testWidgets('manager shell shows four bottom destinations', (tester) async {
    var selected = AppShellDestination.home;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) {
              return AppBottomNavigation(
                currentDestination: selected,
                onDestinationSelected: (destination) {
                  setState(() {
                    selected = destination;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('مالی'), findsOneWidget);
    expect(find.text('سفارشات'), findsOneWidget);
    expect(find.text('گزارشات'), findsOneWidget);
    expect(find.text('منو'), findsOneWidget);

    await tester.tap(find.text('سفارشات'));
    await tester.pump();

    expect(selected, AppShellDestination.orders);
  });
}
