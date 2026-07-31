import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/queries/dashboard_queries.dart';
import '../../../../data/mappers/cheque_mapper.dart';
import '../../../../data/models/cheque.dart';

import '../../domain/models/commitment_period.dart';
import '../../domain/models/commitment_day_summary.dart';
import '../../domain/models/commitment_company_summary.dart';
import '../../domain/models/dashboard_summary.dart';
import '../../domain/models/tomorrow_commitment_summary.dart';

import 'dashboard_repository.dart';

class SqliteDashboardRepository implements DashboardRepository {
  final Database _db;
  static const int _periodCountForDashboard = 12;

  static const List<String> _jalaliMonthNames = <String>[
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

  SqliteDashboardRepository({Database? database})
    : _db = database ?? DatabaseService.instance.database;

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    return DashboardSummary(
      tomorrow: await getTomorrowCommitments(),
      periods: await getCommitmentPeriods(),
      warnings: const [],
    );
  }

  @override
  Future<TomorrowCommitmentSummary> getTomorrowCommitments() async {
    final now = DateTime.now();

    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);

    final tomorrowEnd = tomorrowStart.add(const Duration(days: 1));

    final rows = _db.select(DashboardQueries.tomorrowCommitments, [
      tomorrowStart.millisecondsSinceEpoch,
      tomorrowEnd.millisecondsSinceEpoch,
    ]);

    final commitments = rows.map((row) {
      return BankCommitment(
        bankName: row['bank_account_title'] as String,
        amount: (row['total_amount'] as num).toInt(),
      );
    }).toList();

    return TomorrowCommitmentSummary(
      hasCommitment: commitments.isNotEmpty,
      bankCommitments: commitments,
    );
  }

  @override
  Future<List<Cheque>> getUnregisteredCheques() async {
    final rows = _db.select(DashboardQueries.unregisteredCheques);
    return rows.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<CommitmentPeriod>> getCommitmentPeriods() async {
    final periods = <CommitmentPeriod>[];

    final today = DateTime.now();

    var currentStart = _calculateCurrentPeriodStart(today);

    for (var i = 0; i < _periodCountForDashboard; i++) {
      final end = _calculatePeriodEnd(currentStart);

      int commitmentCount = 0;
      int totalAmount = 0;

      if (currentStart.isBefore(end)) {
        final result = _db.select(DashboardQueries.commitmentPeriodSummary, [
          currentStart.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ]);

        final row = result.first;
        commitmentCount = (row['commitment_count'] as int?) ?? 0;
        totalAmount = (row['total_amount'] as num?)?.toInt() ?? 0;
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

  @override
  Future<List<CommitmentDaySummary>> getCommitmentDaysByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rows = _db.select(DashboardQueries.commitmentDays, [
      startDate.millisecondsSinceEpoch,
      endDate.millisecondsSinceEpoch,
    ]);

    return rows.map((row) {
      return CommitmentDaySummary(
        date: DateTime.fromMillisecondsSinceEpoch(
          (row['day_start'] as num).toInt(),
        ),
        commitmentCount: (row['commitment_count'] as num).toInt(),
        totalAmount: (row['total_amount'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<List<CommitmentCompanySummary>> getCommitmentCompaniesByDay(
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    final rows = _db.select(DashboardQueries.commitmentCompanies, [
      dayStart.millisecondsSinceEpoch,
      dayEnd.millisecondsSinceEpoch,
    ]);

    final grouped = <int, _CompanyAggregate>{};

    for (final row in rows) {
      final companyId = (row['company_id'] as num).toInt();
      final companyName = (row['company_name'] as String?)?.trim() ?? '';
      final bankAccount = (row['bank_account_title'] as String?)?.trim() ?? '';
      final amount = (row['amount_rial'] as num).toInt();
      final chequeNumber = (row['cheque_number'] as Object?)?.toString() ?? '-';

      final aggregate = grouped.putIfAbsent(
        companyId,
        () => _CompanyAggregate(companyName: companyName),
      );

      aggregate.totalAmount += amount;
      aggregate.cheques.add(
        CommitmentChequeSummary(
          chequeNumber: chequeNumber,
          bankAccount: bankAccount,
          amount: amount,
        ),
      );
    }

    final companies = grouped.entries.map((entry) {
      final value = entry.value;

      return CommitmentCompanySummary(
        companyId: entry.key,
        companyName: value.companyName,
        chequeCount: value.cheques.length,
        totalAmount: value.totalAmount,
        cheques: List<CommitmentChequeSummary>.unmodifiable(value.cheques),
      );
    }).toList();

    companies.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return companies;
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
}

class _CompanyAggregate {
  _CompanyAggregate({required this.companyName});

  final String companyName;
  int totalAmount = 0;
  final List<CommitmentChequeSummary> cheques = <CommitmentChequeSummary>[];
}
