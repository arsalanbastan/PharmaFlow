import 'manager_invoice_settlement.dart';
import 'invoice_maturity_planner.dart';

/// Read-only preview of an invoice-specific cash discount. Percentages apply
/// to the CURRENT remaining balance, not the original face value. Values are
/// rounded to the nearest whole Rial, half upwards.
class InvoiceDiscountCalculator {
  const InvoiceDiscountCalculator._();

  static int? basisPoints(String text) {
    var raw = text.trim().replaceAll('٫', '.').replaceAll('٪', '');
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    for (var digit = 0; digit < 10; digit++) {
      raw = raw.replaceAll(persian[digit], '$digit')
          .replaceAll(arabic[digit], '$digit');
    }
    if (raw.isEmpty) return 0;
    final match = RegExp(r'^(\d{1,3})(?:\.(\d{1,2}))?$').firstMatch(raw);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final frac = (match.group(2) ?? '').padRight(2, '0');
    final result = whole * 100 + (frac.isEmpty ? 0 : int.parse(frac));
    return result <= 10000 ? result : null;
  }

  static BigInt? discountRials(String remainingAmount, String percent) {
    final balance = InvoiceMaturityPlan.parseRials(remainingAmount);
    final basis = basisPoints(percent);
    if (balance == null || basis == null) return null;
    return (balance * BigInt.from(basis) + BigInt.from(5000)) ~/
        BigInt.from(10000);
  }

  static Map<String, BigInt>? byInvoice(
    Iterable<InvoiceSettlementItem> invoices,
    Map<String, String> percentages,
  ) {
    final result = <String, BigInt>{};
    for (final invoice in invoices) {
      final discount = discountRials(
          invoice.remainingAmount, percentages[invoice.id] ?? '0');
      if (discount == null) return null;
      result[invoice.id] = discount;
    }
    return result;
  }
}
