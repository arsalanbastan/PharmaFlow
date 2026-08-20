import '../../../../data/models/cash_payment.dart';
import '../../../../data/models/cheque.dart';

enum CompanyAccountActivityKind { cheque, cashPayment }

class CompanyAccountActivityRow {
  const CompanyAccountActivityRow({
    required this.kind,
    required this.effectiveDate,
    required this.amountRial,
    required this.reference,
    required this.method,
    required this.description,
    required this.sourceCreatedAt,
  });

  final CompanyAccountActivityKind kind;
  final DateTime effectiveDate;
  final int amountRial;
  final String reference;
  final String method;
  final String description;
  final DateTime sourceCreatedAt;

  String get typeLabel {
    switch (kind) {
      case CompanyAccountActivityKind.cheque:
        return 'چک';
      case CompanyAccountActivityKind.cashPayment:
        return 'واریزی';
    }
  }
}

List<CompanyAccountActivityRow> buildCompanyAccountActivityRows({
  required int companyId,
  required Iterable<Cheque> cheques,
  required Iterable<CashPayment> cashPayments,
}) {
  final rows = <CompanyAccountActivityRow>[];

  for (final cheque in cheques) {
    if (cheque.companyId != companyId ||
        cheque.status == ChequeStatus.cancelled ||
        cheque.archivedAt != null ||
        cheque.deleteRequestedAt != null) {
      continue;
    }

    rows.add(
      CompanyAccountActivityRow(
        kind: CompanyAccountActivityKind.cheque,
        // Deliberately use ISSUE DATE, not due date.
        effectiveDate: cheque.issueDate,
        amountRial: cheque.amountRial,
        reference: cheque.chequeNumber.trim().isEmpty
            ? '—'
            : cheque.chequeNumber.trim(),
        method: 'چک',
        description: _firstNonEmpty([cheque.description, cheque.receiverName]),
        sourceCreatedAt: cheque.createdAt,
      ),
    );
  }

  for (final payment in cashPayments) {
    if (payment.companyId != companyId ||
        payment.archivedAt != null ||
        payment.deleteRequestedAt != null ||
        payment.deletedAt != null) {
      continue;
    }

    rows.add(
      CompanyAccountActivityRow(
        kind: CompanyAccountActivityKind.cashPayment,
        effectiveDate: payment.paymentDate,
        amountRial: payment.amountRial,
        reference: _firstNonEmpty([payment.trackingNumber]),
        method: _cashPaymentMethodLabel(payment.paymentMethod),
        description: _firstNonEmpty([payment.description, payment.notes]),
        sourceCreatedAt: payment.createdAt,
      ),
    );
  }

  rows.sort((a, b) {
    final dateCompare = b.effectiveDate.compareTo(a.effectiveDate);

    if (dateCompare != 0) {
      return dateCompare;
    }

    final createdCompare = b.sourceCreatedAt.compareTo(a.sourceCreatedAt);

    if (createdCompare != 0) {
      return createdCompare;
    }

    final kindCompare = a.kind.index.compareTo(b.kind.index);

    if (kindCompare != 0) {
      return kindCompare;
    }

    return a.reference.compareTo(b.reference);
  });

  return List<CompanyAccountActivityRow>.unmodifiable(rows);
}

String _cashPaymentMethodLabel(CashPaymentMethod method) {
  switch (method) {
    case CashPaymentMethod.bankDeposit:
      return 'واریز بانکی';
    case CashPaymentMethod.posPayment:
      return 'پرداخت کارتخوان';
  }
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();

    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }

  return '—';
}
