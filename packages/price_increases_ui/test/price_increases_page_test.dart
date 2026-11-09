import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:price_increases_ui/price_increases_page.dart';

void main() {
  test('normalizes Persian and Arabic digits without rounding prices', () {
    expect(normalizePriceInput('۱۲۳٬۴۵۶.۷۸'), '123456.78');
    expect(normalizePriceInput('١٢٣,٤٥٦'), '123456');
    expect(formatPrice('1234567890123456.78'), '1,234,567,890,123,456.78');
  });
  testWidgets('staff sees identity and timestamp and can confirm once', (
    tester,
  ) async {
    bool confirmed = false;
    Future<Map<String, dynamic>> request(
      String path,
      Map<String, dynamic>? body,
    ) async {
      if (body != null) {
        confirmed = true;
        return {};
      }
      return {
        'items': [
          {
            'id': 'item',
            'productName': 'داروی آزمایشی',
            'category': 'DRUG',
            'newPrice': '123456.78',
            'effectiveDate': '1405/08/18',
            'source': 'شرکت',
            'notes': '',
            'createdByName': 'مدیر',
            'createdAt': '2026-11-09T10:00:00Z',
            'attachments': [],
            'confirmations': confirmed
                ? [
                    {
                      'userId': 'staff-1',
                      'displayName': 'کارمند اول',
                      'confirmedAt': '2026-11-09T10:01:00Z',
                    },
                  ]
                : [],
          },
        ],
        'total': 1,
        'currentUserId': 'staff-1',
      };
    }

    await tester.pumpWidget(
      MaterialApp(home: PriceIncreasesPage(request: request, manager: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('داروی آزمایشی'), findsOneWidget);
    expect(find.text('ثبت افزایش قیمت'), findsNothing);
    await tester.ensureVisible(find.text('قیمت جدید را اعمال کردم'));
    await tester.tap(find.text('قیمت جدید را اعمال کردم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعمال کردم'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    expect(find.textContaining('کارمند اول'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'تأیید شما ثبت شده'),
    );
    expect(button.onPressed, isNull);
  });
  testWidgets('failed history request offers retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PriceIncreasesPage(
          manager: false,
          request: (path, body) async => throw StateError('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تلاش مجدد'), findsOneWidget);
    expect(find.text('موردی یافت نشد.'), findsNothing);
  });
}
