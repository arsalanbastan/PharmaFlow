import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:pharmaflow/data/models/bank_account.dart';
import 'package:pharmaflow/data/models/cheque.dart';
import 'package:pharmaflow/features/cheques/presentation/providers/active_cheques_provider.dart';
import 'package:pharmaflow/features/dashboard/presentation/providers/dashboard_provider.dart';

void main() {
  final fixedToday = Jalali(1405, 5, 12).toDateTime();

  ProviderContainer createContainer(List<Cheque> cheques) {
    final lookup = ActiveChequeLookupData(
      cheques: cheques,
      companyNames: const <int, String>{1: 'Company'},
      bankAccountNames: const <int, String>{1: 'Bank'},
      bankAccountsById: <int, BankAccount>{},
    );

    final container = ProviderContainer(
      overrides: [
        dashboardNowProvider.overrideWith((ref) => fixedToday),
        activeChequeLookupProvider.overrideWith((ref) async => lookup),
      ],
    );

    addTearDown(container.dispose);
    return container;
  }

  test('includes cheque from current Mordad period', () async {
    final container = createContainer([
      _cheque(id: 1, dueDate: Jalali(1405, 5, 12).toDateTime()),
    ]);

    final summary = await container.read(dashboardSummaryProvider.future);
    expect(summary.periods, hasLength(1));
    expect(summary.periods.first.commitmentCount, 1);
    expect(summary.periods.first.totalAmount, 1000000);
  });

  test('skips empty periods between populated periods', () async {
    final currentStart = _calculateCurrentPeriodStartForTest(fixedToday);
    final nextPeriodStart = _calculatePeriodEndForTest(currentStart);

    final container = createContainer([
      _cheque(id: 1, dueDate: Jalali(1405, 5, 12).toDateTime()),
      _cheque(id: 2, dueDate: Jalali(1405, 6, 2).toDateTime()),
    ]);

    final summary = await container.read(dashboardSummaryProvider.future);

    expect(summary.periods, hasLength(2));
    expect(
      summary.periods.any((period) => period.startDate == nextPeriodStart),
      isFalse,
    );
  });

  test(
    'includes far-ahead Bahman cheque beyond old 12-period horizon',
    () async {
      final container = createContainer([
        _cheque(id: 1, dueDate: Jalali(1405, 5, 12).toDateTime()),
        _cheque(id: 2, dueDate: Jalali(1405, 11, 12).toDateTime()),
      ]);

      final summary = await container.read(dashboardSummaryProvider.future);

      expect(
        summary.periods.any(
          (period) => period.title.contains('\u0628\u0647\u0645\u0646'),
        ),
        isTrue,
      );
    },
  );

  test('does not include periods before current period', () async {
    final currentStart = _calculateCurrentPeriodStartForTest(fixedToday);

    final container = createContainer([
      _cheque(id: 1, dueDate: Jalali(1405, 4, 28).toDateTime()),
      _cheque(id: 2, dueDate: Jalali(1405, 5, 12).toDateTime()),
    ]);

    final summary = await container.read(dashboardSummaryProvider.future);

    expect(
      summary.periods.every(
        (period) => !period.startDate.isBefore(currentStart),
      ),
      isTrue,
    );
  });

  test('cancelled cheque does not make an empty period appear', () async {
    final currentStart = _calculateCurrentPeriodStartForTest(fixedToday);
    final nextPeriodStart = _calculatePeriodEndForTest(currentStart);

    final container = createContainer([
      _cheque(id: 1, dueDate: Jalali(1405, 5, 12).toDateTime()),
      _cheque(
        id: 2,
        dueDate: Jalali(1405, 5, 20).toDateTime(),
        status: ChequeStatus.cancelled,
      ),
      _cheque(id: 3, dueDate: Jalali(1405, 6, 2).toDateTime()),
    ]);

    final summary = await container.read(dashboardSummaryProvider.future);

    expect(
      summary.periods.any((period) => period.startDate == nextPeriodStart),
      isFalse,
    );
  });

  test('returns periods in chronological order', () async {
    final container = createContainer([
      _cheque(id: 1, dueDate: Jalali(1405, 11, 12).toDateTime()),
      _cheque(id: 2, dueDate: Jalali(1405, 5, 12).toDateTime()),
      _cheque(id: 3, dueDate: Jalali(1405, 7, 8).toDateTime()),
    ]);

    final summary = await container.read(dashboardSummaryProvider.future);

    for (var i = 1; i < summary.periods.length; i++) {
      expect(
        summary.periods[i - 1].startDate.isAfter(summary.periods[i].startDate),
        isFalse,
      );
    }
  });

  test(
    'returns empty periods when no eligible current/future cheques',
    () async {
      final container = createContainer([
        _cheque(id: 1, dueDate: Jalali(1405, 4, 28).toDateTime()),
        _cheque(
          id: 2,
          dueDate: Jalali(1405, 11, 12).toDateTime(),
          status: ChequeStatus.cancelled,
        ),
      ]);

      final summary = await container.read(dashboardSummaryProvider.future);
      expect(summary.periods, isEmpty);
    },
  );
}

Cheque _cheque({
  required int id,
  required DateTime dueDate,
  ChequeStatus status = ChequeStatus.issued,
}) {
  final issueDate = dueDate.subtract(const Duration(days: 10));

  return Cheque(
    id: id,
    serverUuid: 'server-$id',
    companyId: 1,
    bankAccountId: 1,
    chequeNumber: '$id',
    amountRial: 1000000,
    issueDate: issueDate,
    dueDate: dueDate,
    status: status,
    isRegisteredInSayad: false,
    createdAt: issueDate,
    updatedAt: issueDate,
  );
}

DateTime _calculateCurrentPeriodStartForTest(DateTime date) {
  final jDate = Jalali.fromDateTime(date);
  final day = jDate.day;

  if (day >= 6 && day <= 15) {
    return Jalali(jDate.year, jDate.month, 6).toDateTime();
  }

  if (day >= 16 && day <= 25) {
    return Jalali(jDate.year, jDate.month, 16).toDateTime();
  }

  if (day >= 26) {
    return Jalali(jDate.year, jDate.month, 26).toDateTime();
  }

  final previousMonth = jDate.month == 1
      ? Jalali(jDate.year - 1, 12, 25)
      : Jalali(jDate.year, jDate.month - 1, 25);

  return previousMonth.toDateTime();
}

DateTime _calculatePeriodEndForTest(DateTime start) {
  final jDate = Jalali.fromDateTime(start);

  if (jDate.day == 6) {
    return Jalali(jDate.year, jDate.month, 16).toDateTime();
  }

  if (jDate.day == 16) {
    return Jalali(jDate.year, jDate.month, 26).toDateTime();
  }

  final nextMonth = jDate.month == 12
      ? Jalali(jDate.year + 1, 1, 5)
      : Jalali(jDate.year, jDate.month + 1, 5);

  return nextMonth.addDays(1).toDateTime();
}
