import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/features/orders/presentation/staff_order_form_page.dart';

void main() {
  testWidgets('shows live active-order similarities below the item field', (
    tester,
  ) async {
    var lookupCount = 0;

    Future<Map<String, dynamic>> lookup({
      required String category,
      required String itemText,
    }) async {
      lookupCount += 1;

      expect(category, 'DRUG');
      expect(itemText, 'آتروواستاتین');

      return {
        'found': true,
        'matches': [
          {
            'id': '11111111-1111-4111-8111-111111111111',
            'itemText': 'قرص آتورواستاتین 20',
            'status': 'PENDING',
          },
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'itemText': 'اتورواستاتین 20',
            'status': 'ORDERED',
          },
        ],
      };
    }

    await tester.pumpWidget(
      MaterialApp(home: StaffOrderFormPage(duplicateLookup: lookup)),
    );

    await tester.enterText(find.byType(TextFormField).first, 'آتروواستاتین');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(lookupCount, 1);
    expect(find.text('سفارش‌های مشابه'), findsOneWidget);
    expect(find.text('قرص آتورواستاتین 20'), findsOneWidget);
    expect(find.text('اتورواستاتین 20'), findsOneWidget);
    expect(find.text('هنوز به شرکت داده نشده'), findsOneWidget);
    expect(find.text('به شرکت داده شده؛ در انتظار دریافت'), findsOneWidget);
  });
}
