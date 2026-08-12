import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../core/database/database_service.dart';
import '../../../../data/models/cheque.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../cheques/presentation/providers/active_cheques_provider.dart';
import '../../domain/models/commitment_day_summary.dart';
import '../../domain/models/commitment_company_summary.dart';
import '../../domain/models/dashboard_summary.dart';
import '../../domain/models/commitment_period.dart';
import '../../domain/models/tomorrow_commitment_summary.dart';

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final lookup = await ref.watch(activeChequeLookupProvider.future);
  final filtered = commitmentEligibleCheques(lookup.cheques);

  return DashboardSummary(
    tomorrow: _tomorrowSummary(
      cheques: filtered,
      bankAccountNames: lookup.bankAccountNames,
    ),
    periods: _buildPeriods(filtered),
    warnings: const [],
  );
});

class CommitmentPeriodRange {
  final DateTime startDate;
  final DateTime endDate;

  const CommitmentPeriodRange({required this.startDate, required this.endDate});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CommitmentPeriodRange &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(startDate, endDate);
}

final commitmentDaysByPeriodProvider =
    FutureProvider.family<List<CommitmentDaySummary>, CommitmentPeriodRange>((
      ref,
      range,
    ) async {
      final cheques = await ref.watch(activeChequesProvider.future);

      return _commitmentDaysByPeriod(
        cheques: commitmentEligibleCheques(cheques),
        startDate: range.startDate,
        endDate: range.endDate,
      );
    });

class CommitmentDayRange {
  final DateTime dayStart;
  final DateTime dayEnd;

  const CommitmentDayRange({required this.dayStart, required this.dayEnd});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CommitmentDayRange &&
        other.dayStart == dayStart &&
        other.dayEnd == dayEnd;
  }

  @override
  int get hashCode => Object.hash(dayStart, dayEnd);
}

final commitmentCompaniesByDayProvider =
    FutureProvider.family<List<CommitmentCompanySummary>, CommitmentDayRange>((
      ref,
      range,
    ) async {
      final lookup = await ref.watch(activeChequeLookupProvider.future);

      return _commitmentCompaniesByDay(
        cheques: commitmentEligibleCheques(lookup.cheques),
        companyNames: lookup.companyNames,
        bankAccountNames: lookup.bankAccountNames,
        dayStart: range.dayStart,
        dayEnd: range.dayEnd,
      );
    });

typedef UnregisteredChequesCardData = ({
  List<Cheque> cheques,
  Map<int, String> companyNames,
  Map<int, String> bankAccountNames,
});

final unregisteredChequesCardProvider =
    FutureProvider<UnregisteredChequesCardData>((ref) async {
      final lookup = await ref.watch(activeChequeLookupProvider.future);

      final cheques = lookup.cheques
          .where((cheque) => !cheque.isRegisteredInSayad)
          .toList(growable: false);

      return (
        cheques: cheques,
        companyNames: lookup.companyNames,
        bankAccountNames: lookup.bankAccountNames,
      );
    });

final markChequeAsRegisteredProvider =
    Provider<Future<void> Function(Cheque cheque)>((ref) {
      final chequeRepository = LocalChequeRepository(DatabaseService.instance);

      return (Cheque cheque) async {
        final latest = await chequeRepository.findById(cheque.id);
        if (latest == null) {
          throw StateError('Cheque ${cheque.id} not found locally.');
        }

        await chequeRepository.update(
          latest.copyWith(isRegisteredInSayad: true, updatedAt: DateTime.now()),
        );

        invalidateChequeDependentProviders(ref.container);
      };
    });

const List<String> _jalaliMonthNames = <String>[
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

const int _periodCountForDashboard = 12;

List<Cheque> commitmentEligibleCheques(List<Cheque> cheques) {
  return cheques
      .where((cheque) => cheque.status != ChequeStatus.cancelled)
      .toList(growable: false);
}

TomorrowCommitmentSummary _tomorrowSummary({
  required List<Cheque> cheques,
  required Map<int, String> bankAccountNames,
}) {
  final now = DateTime.now();
  final tomorrowStart = DateTime(now.year, now.month, now.day + 1);
  final tomorrowEnd = tomorrowStart.add(const Duration(days: 1));

  final sums = <int, int>{};
  for (final cheque in cheques) {
    final dueDate = cheque.dueDate;
    if (!_isInRange(dueDate, tomorrowStart, tomorrowEnd)) {
      continue;
    }

    sums.update(
      cheque.bankAccountId,
      (value) => value + cheque.amountRial,
      ifAbsent: () => cheque.amountRial,
    );
  }

  final commitments =
      sums.entries
          .map(
            (entry) => BankCommitment(
              bankName: bankAccountNames[entry.key] ?? '—',
              amount: entry.value,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => b.amount.compareTo(a.amount));

  return TomorrowCommitmentSummary(
    hasCommitment: commitments.isNotEmpty,
    bankCommitments: commitments,
  );
}

List<CommitmentPeriod> _buildPeriods(List<Cheque> cheques) {
  final periods = <CommitmentPeriod>[];

  final today = DateTime.now();
  var currentStart = _calculateCurrentPeriodStart(today);

  for (var i = 0; i < _periodCountForDashboard; i++) {
    final end = _calculatePeriodEnd(currentStart);

    var commitmentCount = 0;
    var totalAmount = 0;

    for (final cheque in cheques) {
      if (_isInRange(cheque.dueDate, currentStart, end)) {
        commitmentCount += 1;
        totalAmount += cheque.amountRial;
      }
    }

    periods.add(
      CommitmentPeriod(
        title: _periodTitle(currentStart, end),
        startDate: currentStart,
        endDate: end,
        commitmentCount: commitmentCount,
        totalAmount: totalAmount,
      ),
    );

    currentStart = end;
  }

  return periods;
}

List<CommitmentDaySummary> _commitmentDaysByPeriod({
  required List<Cheque> cheques,
  required DateTime startDate,
  required DateTime endDate,
}) {
  final grouped = <DateTime, _DayAggregate>{};

  for (final cheque in cheques) {
    if (!_isInRange(cheque.dueDate, startDate, endDate)) {
      continue;
    }

    final dayStart = DateTime(
      cheque.dueDate.year,
      cheque.dueDate.month,
      cheque.dueDate.day,
    );

    final aggregate = grouped.putIfAbsent(
      dayStart,
      () => const _DayAggregate(),
    );
    grouped[dayStart] = aggregate.copyWith(
      commitmentCount: aggregate.commitmentCount + 1,
      totalAmount: aggregate.totalAmount + cheque.amountRial,
    );
  }

  final summaries =
      grouped.entries
          .map(
            (entry) => CommitmentDaySummary(
              date: entry.key,
              commitmentCount: entry.value.commitmentCount,
              totalAmount: entry.value.totalAmount,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));

  return summaries;
}

List<CommitmentCompanySummary> _commitmentCompaniesByDay({
  required List<Cheque> cheques,
  required Map<int, String> companyNames,
  required Map<int, String> bankAccountNames,
  required DateTime dayStart,
  required DateTime dayEnd,
}) {
  final grouped = <int, _CompanyAggregate>{};

  for (final cheque in cheques) {
    if (!_isInRange(cheque.dueDate, dayStart, dayEnd)) {
      continue;
    }

    final aggregate = grouped.putIfAbsent(
      cheque.companyId,
      () =>
          _CompanyAggregate(companyName: companyNames[cheque.companyId] ?? '—'),
    );

    aggregate.totalAmount += cheque.amountRial;
    aggregate.cheques.add(
      CommitmentChequeSummary(
        chequeNumber: cheque.chequeNumber,
        bankAccount: bankAccountNames[cheque.bankAccountId] ?? '—',
        amount: cheque.amountRial,
      ),
    );
  }

  final companies =
      grouped.entries
          .map(
            (entry) => CommitmentCompanySummary(
              companyId: entry.key,
              companyName: entry.value.companyName,
              chequeCount: entry.value.cheques.length,
              totalAmount: entry.value.totalAmount,
              cheques: List<CommitmentChequeSummary>.unmodifiable(
                entry.value.cheques,
              ),
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

  return companies;
}

bool _isInRange(DateTime value, DateTime start, DateTime end) {
  return !value.isBefore(start) && value.isBefore(end);
}

DateTime _calculateCurrentPeriodStart(DateTime date) {
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

DateTime _calculatePeriodEnd(DateTime start) {
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

String _periodTitle(DateTime start, DateTime end) {
  final s = Jalali.fromDateTime(start);
  final e = Jalali.fromDateTime(end);

  final periodLabel = switch (s.day) {
    25 => 'دوره اول',
    26 => 'دوره اول',
    6 => 'دوره دوم',
    16 => 'دوره سوم',
    _ => 'دوره',
  };

  final monthNumber = (s.day == 25 || s.day == 26) ? e.month : s.month;
  final monthName = _jalaliMonthNames[monthNumber - 1];

  return '$periodLabel $monthName';
}

class _DayAggregate {
  const _DayAggregate({this.commitmentCount = 0, this.totalAmount = 0});

  final int commitmentCount;
  final int totalAmount;

  _DayAggregate copyWith({int? commitmentCount, int? totalAmount}) {
    return _DayAggregate(
      commitmentCount: commitmentCount ?? this.commitmentCount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}

class _CompanyAggregate {
  _CompanyAggregate({required this.companyName});

  final String companyName;
  int totalAmount = 0;
  final List<CommitmentChequeSummary> cheques = <CommitmentChequeSummary>[];
}
