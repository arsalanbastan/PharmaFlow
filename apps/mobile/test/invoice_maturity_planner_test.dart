import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:pharmaflow/features/invoices/domain/invoice_maturity_planner.dart';
import 'package:pharmaflow/features/invoices/domain/manager_invoice_settlement.dart';

InvoiceSettlementItem item(String due, String amount) =>
    InvoiceSettlementItem.fromJson(<String, dynamic>{
      'id': 'test-$due-$amount',
      'invoiceNumber': 'TEST',
      'invoiceDate': '1405/01/01',
      'settlementDate': due,
      'factorPayablePrice': amount,
      'paidAmount': '0',
      'discountAmount': '0',
      'remainingAmount': amount,
    });

void main() {
  test('preserves exact Rial amounts beyond double integer precision', () {
    final plan = InvoiceMaturityPlan.fromInvoices([
      item('1405/06/15', '9007199254740993.0000'),
    ])!;
    expect(plan.totalRials, BigInt.parse('9007199254740993'));
    expect(plan.originalMaturityJalali, '1405/06/15');
    expect(InvoiceMaturityPlan.formatRials(plan.totalRials),
        '9,007,199,254,740,993');
  });

  test('cash offsets 20-day cheque delay without altering original maturity', () {
    final due = Jalali(1405, 6, 15);
    final cash = Jalali.fromDateTime(due.toDateTime().subtract(
      const Duration(days: 20),
    ));
    final cheque = Jalali.fromDateTime(due.toDateTime().add(
      const Duration(days: 20),
    ));
    final plan = InvoiceMaturityPlan.fromInvoices([
      item('1405/06/15', '1000'),
    ])!;
    final minimum = plan.minimumCashForDelayDays(20, cash);
    expect(minimum, BigInt.from(500));
    final balanced = plan.previewFullSettlement(
      chequeRials: BigInt.from(500),
      chequeDueDate: cheque,
      cashRials: BigInt.from(500),
      cashDate: cash,
    )!;
    expect(balanced.dayDifferenceTenths, 0);
    expect(plan.originalMaturityJalali, '1405/06/15');
    final deferred = plan.previewFullSettlement(
      chequeRials: BigInt.from(1000),
      chequeDueDate: cheque,
      cashRials: BigInt.zero,
      cashDate: cash,
    )!;
    expect(deferred.dayDifferenceTenths, 200);
    expect(deferred.formattedDayDifference, '+20.0');
  });

  test('weighted baseline respects different due dates and remaining amounts', () {
    final original = Jalali(1405, 6, 15);
    final later = Jalali.fromDateTime(original.toDateTime().add(
      const Duration(days: 10),
    ));
    final laterText = '${later.year}/${later.month.toString().padLeft(2, '0')}/'
        '${later.day.toString().padLeft(2, '0')}';
    final plan = InvoiceMaturityPlan.fromInvoices([
      item('1405/06/15', '100'),
      item(laterText, '300'),
    ])!;
    expect(plan.totalRials, BigInt.from(400));
    expect(plan.originalRoundedEpochDay, InvoiceMaturityPlan.fromInvoices([
      item('1405/06/15', '1'),
    ])!.originalRoundedEpochDay + 8);
  });

  test('does not invent due date, accept fractional Rials, or compare partial pay', () {
    expect(InvoiceMaturityPlan.fromInvoices([item('', '100')]), isNull);
    expect(InvoiceMaturityPlan.fromInvoices([item('1405/06/15', '100.5')]),
        isNull);
    final plan = InvoiceMaturityPlan.fromInvoices([
      item('1405/06/15', '1000'),
    ])!;
    expect(plan.previewFullSettlement(
      chequeRials: BigInt.from(800),
      chequeDueDate: Jalali(1405, 7, 1),
      cashRials: BigInt.zero,
      cashDate: Jalali(1405, 6, 1),
    ), isNull);
    expect(plan.minimumCashForDelayDays(365, Jalali(1405, 6, 16)), isNull);
  });
}