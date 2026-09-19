import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/data/models/cash_payment.dart';
import 'package:pharmaflow/data/models/cheque.dart';
import 'package:pharmaflow/features/reports/presentation/models/company_account_activity_report_data.dart';

void main() {
  test('company activity sorts cheque by issueDate, not dueDate', () {
    final createdAt = DateTime.utc(2026, 1, 1);

    final cheque = Cheque(
      id: 1,
      companyId: 10,
      bankAccountId: 20,
      chequeNumber: '1001',
      amountRial: 1000000,
      issueDate: DateTime.utc(2026, 1, 10),
      // Deliberately later than the cash payment date.
      dueDate: DateTime.utc(2026, 3, 10),
      status: ChequeStatus.issued,
      isRegisteredInSayad: false,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final payment = CashPayment(
      id: 2,
      amountRial: 2000000,
      paymentDate: DateTime.utc(2026, 2, 10),
      companyId: 10,
      bankAccountId: 20,
      paymentMethod: CashPaymentMethod.bankDeposit,
      trackingNumber: '555',
      createdAt: createdAt.add(const Duration(days: 1)),
      updatedAt: createdAt.add(const Duration(days: 1)),
    );

    final rows = buildCompanyAccountActivityRows(
      companyId: 10,
      cheques: [cheque],
      cashPayments: [payment],
    );

    expect(rows, hasLength(2));
    expect(rows.first.kind, CompanyAccountActivityKind.cashPayment);
    expect(rows.last.kind, CompanyAccountActivityKind.cheque);
    expect(rows.last.effectiveDate, cheque.issueDate);
  });

  test('cancelled cheques and deleted cash payments are excluded', () {
    final now = DateTime.utc(2026, 2, 1);

    final cancelledCheque = Cheque(
      id: 1,
      companyId: 10,
      bankAccountId: 20,
      chequeNumber: '1002',
      amountRial: 1000000,
      issueDate: now,
      dueDate: now.add(const Duration(days: 10)),
      status: ChequeStatus.cancelled,
      isRegisteredInSayad: false,
      createdAt: now,
      updatedAt: now,
    );

    final deletedPayment = CashPayment(
      id: 2,
      amountRial: 2000000,
      paymentDate: now,
      companyId: 10,
      bankAccountId: 20,
      paymentMethod: CashPaymentMethod.posPayment,
      deletedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final rows = buildCompanyAccountActivityRows(
      companyId: 10,
      cheques: [cancelledCheque],
      cashPayments: [deletedPayment],
    );

    expect(rows, isEmpty);
  });
}
