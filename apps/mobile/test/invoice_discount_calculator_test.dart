import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/features/invoices/domain/invoice_discount_calculator.dart';
import 'package:pharmaflow/features/invoices/domain/manager_invoice_settlement.dart';

InvoiceSettlementItem sample(String id, String amount) =>
    InvoiceSettlementItem.fromJson(<String, dynamic>{
      'id': id,
      'invoiceNumber': id,
      'invoiceDate': '1405/06/01',
      'settlementDate': '1405/07/01',
      'factorPayablePrice': amount,
      'paidAmount': '0',
      'discountAmount': '0',
      'remainingAmount': amount,
    });

void main() {
  test('applies separate percentages to each invoice CURRENT balance', () {
    final amounts = InvoiceDiscountCalculator.byInvoice(
      [sample('a', '10000000'), sample('b', '4000000')],
      {'a': '12', 'b': '5.5'},
    )!;
    expect(amounts['a'], BigInt.from(1200000));
    expect(amounts['b'], BigInt.from(220000));
    expect(amounts.values.reduce((a, b) => a + b), BigInt.from(1420000));
  });

  test('rounds half a Rial upwards without floating point', () {
    expect(InvoiceDiscountCalculator.discountRials('1', '50'), BigInt.one);
    expect(InvoiceDiscountCalculator.discountRials('9007199254740993', '100'),
        BigInt.parse('9007199254740993'));
  });

  test('rejects invalid discounts and percentages outside 0-100', () {
    expect(InvoiceDiscountCalculator.discountRials('1000', '100.01'), isNull);
    expect(InvoiceDiscountCalculator.discountRials('1000', '-1'), isNull);
    expect(InvoiceDiscountCalculator.discountRials('1000', '12.345'), isNull);
    expect(InvoiceDiscountCalculator.discountRials('1000.5', '12'), isNull);
  });
}
