import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmaflow/features/menu/presentation/pages/menu_page.dart';

void main() {
  testWidgets('Users is removed from Menu and remains under Settings', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MenuPage()));

    expect(find.text('کاربران'), findsNothing);
    expect(find.text('تنظیمات'), findsOneWidget);

    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();

    expect(find.text('کاربران و دسترسی‌ها'), findsOneWidget);
  });
}
