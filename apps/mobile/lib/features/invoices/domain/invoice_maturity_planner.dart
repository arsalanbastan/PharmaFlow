import 'package:shamsi_date/shamsi_date.dart';

import 'manager_invoice_settlement.dart';

/// A read-only maturity estimate based on the CURRENT unpaid principal of
/// selected invoices. It never changes the invoice's original due date.
/// Dates are calendar days, and amounts use integer Rials (not floating point).
class InvoiceMaturityPlan {
  InvoiceMaturityPlan._(this.totalRials, this._originalWeightedDays);

  final BigInt totalRials;
  final BigInt _originalWeightedDays;
  static const int _millisecondsPerDay = 86400000;

  /// Returns null rather than inventing maturity data for an invoice whose
  /// due date or remaining amount is missing, invalid, or fractional.
  static InvoiceMaturityPlan? fromInvoices(
    Iterable<InvoiceSettlementItem> invoices,
  ) {
    var principal = BigInt.zero;
    var weightedDays = BigInt.zero;
    var hasPositiveBalance = false;
    for (final invoice in invoices) {
      final amount = parseRials(invoice.remainingAmount);
      if (amount == null) return null;
      if (amount == BigInt.zero) continue;
      hasPositiveBalance = true;
      final day = _parseJalaliEpochDay(invoice.settlementDate);
      if (day == null) return null;
      principal += amount;
      weightedDays += amount * BigInt.from(day);
    }
    if (!hasPositiveBalance || principal == BigInt.zero) return null;
    return InvoiceMaturityPlan._(principal, weightedDays);
  }

  static BigInt? parseRials(String value) {
    final normalized = value.replaceAll(',', '').trim();
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(normalized);
    if (match == null) return null;
    final fraction = match.group(2);
    if (fraction != null && fraction.contains(RegExp(r'[1-9]'))) {
      return null;
    }
    return BigInt.tryParse(match.group(1)!);
  }

  static String formatRials(BigInt value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    if (value < BigInt.zero) buffer.write('-');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// The display date is rounded to the nearest calendar day; the exact
  /// unrounded weighted sum is retained for all money calculations.
  int get originalRoundedEpochDay => _roundDiv(
    _originalWeightedDays,
    totalRials,
  ).toInt();

  String get originalMaturityJalali =>
      jalaliForEpochDay(originalRoundedEpochDay);

  String targetChequeJalali(int daysAfterOriginal) =>
      jalaliForEpochDay(originalRoundedEpochDay + daysAfterOriginal);

  /// Minimum cash today (or on cashDate) that keeps the mathematical weighted
  /// payment date at or before the ORIGINAL weighted maturity if all remaining
  /// principal is settled using that cash and ONE cheque at the target date.
  /// Returns null when cash cannot mathematically offset the delayed cheque.
  BigInt? minimumCashForDelayDays(int delayDays, Jalali cashDate) {
    if (delayDays < 0 || delayDays > 365) return null;
    final chequeDay = originalRoundedEpochDay + delayDays;
    final cashDay = _jalaliEpochDay(cashDate);
    if (chequeDay < cashDay) return null;
    final required = totalRials * BigInt.from(chequeDay) -
        _originalWeightedDays;
    if (required <= BigInt.zero) return BigInt.zero;
    final interval = chequeDay - cashDay;
    if (interval <= 0) return null;
    final intervalBig = BigInt.from(interval);
    final cash = (required + intervalBig - BigInt.one) ~/ intervalBig;
    return cash <= totalRials ? cash : null;
  }

  /// A comparable preview requires full payment by cheque and/or cash,
  /// with NO discount or leftover balance. It is never persisted.
  InvoiceMaturityScenario? previewFullSettlement({
    required BigInt chequeRials,
    required Jalali? chequeDueDate,
    required BigInt cashRials,
    required Jalali cashDate,
  }) {
    if (chequeRials < BigInt.zero || cashRials < BigInt.zero ||
        chequeRials + cashRials != totalRials ||
        (chequeRials > BigInt.zero && chequeDueDate == null)) {
      return null;
    }
    final weightedPaymentDays =
        chequeRials * BigInt.from(chequeDueDate == null
            ? 0
            : _jalaliEpochDay(chequeDueDate)) +
        cashRials * BigInt.from(_jalaliEpochDay(cashDate));
    final differenceTenths = _roundDiv(
      (weightedPaymentDays - _originalWeightedDays) * BigInt.from(10),
      totalRials,
    ).toInt();
    final actualRoundedDay = _roundDiv(weightedPaymentDays, totalRials).toInt();
    return InvoiceMaturityScenario(
      actualMaturityJalali: jalaliForEpochDay(actualRoundedDay),
      dayDifferenceTenths: differenceTenths,
    );
  }

  static String jalaliForEpochDay(int day) {
    final utcDate = DateTime.utc(1970, 1, 1).add(Duration(days: day));
    final date = Jalali.fromDateTime(utcDate);
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static int _jalaliEpochDay(Jalali value) {
    final date = value.toGregorian();
    return DateTime.utc(date.year, date.month, date.day)
            .millisecondsSinceEpoch ~/
        _millisecondsPerDay;
  }

  static int? _parseJalaliEpochDay(String? text) {
    if (text == null) return null;
    final match = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$')
        .firstMatch(text.trim());
    if (match == null) return null;
    try {
      final date = Jalali(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
      return _jalaliEpochDay(date);
    } on Exception {
      return null;
    }
  }

  /// Round to nearest integer, halfway away from zero (also for negative deltas).
  static BigInt _roundDiv(BigInt numerator, BigInt denominator) {
    if (numerator < BigInt.zero) {
      return -((-numerator * BigInt.from(2) + denominator) ~/
          (denominator * BigInt.from(2)));
    }
    return (numerator * BigInt.from(2) + denominator) ~/
        (denominator * BigInt.from(2));
  }
}

class InvoiceMaturityScenario {
  const InvoiceMaturityScenario({
    required this.actualMaturityJalali,
    required this.dayDifferenceTenths,
  });

  final String actualMaturityJalali;
  /// Positive means later than the original weighted maturity.
  final int dayDifferenceTenths;

  String get formattedDayDifference {
    final absolute = dayDifferenceTenths.abs();
    final sign = dayDifferenceTenths > 0 ? '+' : dayDifferenceTenths < 0 ? '-' : '';
    return '$sign${absolute ~/ 10}.${absolute % 10}';
  }
}