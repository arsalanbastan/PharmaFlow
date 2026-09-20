import 'manager_invoice.dart';

class InvoiceSettlementBankAccount {
  const InvoiceSettlementBankAccount({
    required this.id,
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
  });

  final String id;
  final String bankName;
  final String? accountTitle;
  final String? accountNumber;

  String get displayName {
    final title = accountTitle?.trim();
    return title == null || title.isEmpty ? bankName : '$bankName — $title';
  }

  factory InvoiceSettlementBankAccount.fromJson(Map<String, dynamic> json) {
    return InvoiceSettlementBankAccount(
      id: _requiredText(json['id'], 'bankAccount.id'),
      bankName: _requiredText(json['bankName'], 'bankAccount.bankName'),
      accountTitle: _optionalText(json['accountTitle']),
      accountNumber: _optionalText(json['accountNumber']),
    );
  }
}

class InvoiceSettlementItem {
  const InvoiceSettlementItem({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.settlementDate,
    required this.paymentDays,
    required this.factorPayablePrice,
    required this.paidAmount,
    required this.discountAmount,
    required this.remainingAmount,
  });

  final String id;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? settlementDate;
  final int? paymentDays;
  final String factorPayablePrice;
  final String paidAmount;
  final String discountAmount;
  final String remainingAmount;

  factory InvoiceSettlementItem.fromJson(Map<String, dynamic> json) {
    return InvoiceSettlementItem(
      id: _requiredText(json['id'], 'invoice.id'),
      invoiceNumber: _optionalText(json['invoiceNumber']),
      invoiceDate: _optionalText(json['invoiceDate']),
      settlementDate: _optionalText(json['settlementDate']),
      paymentDays: int.tryParse(json['paymentDays']?.toString() ?? ''),
      factorPayablePrice: _requiredDecimal(
        json['factorPayablePrice'],
        'factorPayablePrice',
      ),
      paidAmount: _requiredDecimal(json['paidAmount'], 'paidAmount'),
      discountAmount: _requiredDecimal(
        json['discountAmount'],
        'discountAmount',
      ),
      remainingAmount: _requiredDecimal(
        json['remainingAmount'],
        'remainingAmount',
      ),
    );
  }
}

class InvoiceSettlementPreparation {
  const InvoiceSettlementPreparation({
    required this.company,
    required this.invoices,
    required this.totalRemainingAmount,
    required this.bankAccounts,
  });

  final ManagerInvoiceCompany company;
  final List<InvoiceSettlementItem> invoices;
  final String totalRemainingAmount;
  final List<InvoiceSettlementBankAccount> bankAccounts;

  factory InvoiceSettlementPreparation.fromJson(Map<String, dynamic> json) {
    final rawCompany = json['company'];
    final rawInvoices = json['invoices'];
    final rawBankAccounts = json['bankAccounts'];

    if (rawCompany is! Map<String, dynamic> ||
        rawInvoices is! List<dynamic> ||
        rawBankAccounts is! List<dynamic>) {
      throw const FormatException('Invoice settlement response is invalid.');
    }

    return InvoiceSettlementPreparation(
      company: ManagerInvoiceCompany.fromJson(rawCompany),
      invoices: rawInvoices
          .map(
            (raw) =>
                InvoiceSettlementItem.fromJson(raw as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalRemainingAmount: _requiredDecimal(
        json['totalRemainingAmount'],
        'totalRemainingAmount',
      ),
      bankAccounts: rawBankAccounts
          .map(
            (raw) => InvoiceSettlementBankAccount.fromJson(
              raw as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

String _requiredText(Object? value, String field) {
  final normalized = _optionalText(value);
  if (normalized == null) {
    throw FormatException('$field is missing.');
  }
  return normalized;
}

String? _optionalText(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _requiredDecimal(Object? value, String field) =>
    _requiredText(value, field);
