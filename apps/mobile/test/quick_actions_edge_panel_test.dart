import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/shared/quick_actions/quick_actions_edge_panel.dart';

void main() {
  testWidgets('outside tap closes panel and still reaches underlying control', (
    tester,
  ) async {
    var underlyingTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickActionsEdgePanel(
            onAddCheque: ({required bool replaceCurrent}) async {},
            onAddCashPayment: ({required bool replaceCurrent}) async {},
            child: Center(
              child: FilledButton(
                key: const ValueKey('underlying-button'),
                onPressed: () {
                  underlyingTapCount++;
                },
                child: const Text('Underlying'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('quick-actions-collapsed')));
    await tester.pumpAndSettle();

    expect(find.text('میانبرها'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('underlying-button')));
    await tester.pumpAndSettle();

    expect(underlyingTapCount, 1);
    expect(find.text('میانبرها'), findsNothing);
  });

  testWidgets(
    'second quick action requests replacement while first is active',
    (tester) async {
      final firstRouteCompleter = Completer<void>();
      final replaceFlags = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionsEdgePanel(
              onAddCheque: ({required bool replaceCurrent}) {
                replaceFlags.add(replaceCurrent);
                return firstRouteCompleter.future;
              },
              onAddCashPayment: ({required bool replaceCurrent}) async {
                replaceFlags.add(replaceCurrent);
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('quick-actions-collapsed')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ثبت چک'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('quick-actions-collapsed')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ثبت واریزی'));
      await tester.pumpAndSettle();

      expect(replaceFlags, <bool>[false, true]);

      firstRouteCompleter.complete();
      await tester.pump();
    },
  );
}
