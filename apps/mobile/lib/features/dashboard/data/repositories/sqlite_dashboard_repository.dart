import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/queries/dashboard_queries.dart';

import '../../domain/models/commitment_period.dart';
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
  Future<List<CommitmentPeriod>> getCommitmentPeriods() async {
    final periods = <CommitmentPeriod>[];

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    var currentStart = _calculateCurrentPeriodStart(today);

    for (var i = 0; i < _periodCountForDashboard; i++) {
      final end = _calculatePeriodEnd(currentStart);

      final queryStart = currentStart.isBefore(todayStart)
          ? todayStart
          : currentStart;

      int commitmentCount = 0;
      int totalAmount = 0;

      if (queryStart.isBefore(end)) {
        final result = _db.select(DashboardQueries.commitmentPeriodSummary, [
          queryStart.millisecondsSinceEpoch,
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

  DateTime _calculateCurrentPeriodStart(DateTime date) {
    final jDate = Jalali.fromDateTime(date);

    final day = jDate.day;

    if (day >= 5 && day < 15) {
      return Jalali(jDate.year, jDate.month, 5).toDateTime();
    }

    if (day >= 15 && day < 25) {
      return Jalali(jDate.year, jDate.month, 15).toDateTime();
    }

    if (day >= 25) {
      return Jalali(jDate.year, jDate.month, 25).toDateTime();
    }

    final previousMonth = jDate.month == 1
        ? Jalali(jDate.year - 1, 12, 25)
        : Jalali(jDate.year, jDate.month - 1, 25);

    return previousMonth.toDateTime();
  }

  DateTime _calculatePeriodEnd(DateTime start) {
    final jDate = Jalali.fromDateTime(start);

    if (jDate.day == 5) {
      return Jalali(jDate.year, jDate.month, 15).toDateTime();
    }

    if (jDate.day == 15) {
      return Jalali(jDate.year, jDate.month, 25).toDateTime();
    }

    final nextMonth = jDate.month == 12
        ? Jalali(jDate.year + 1, 1, 5)
        : Jalali(jDate.year, jDate.month + 1, 5);

    return nextMonth.toDateTime();
  }

  String _periodTitle(DateTime start, DateTime end) {
    final s = Jalali.fromDateTime(start);
    final e = Jalali.fromDateTime(end);

    final periodLabel = switch (s.day) {
      25 => 'دوره اول',
      5 => 'دوره دوم',
      15 => 'دوره سوم',
      _ => 'دوره',
    };

    final monthNumber = s.day == 25 ? e.month : s.month;
    final monthName = _jalaliMonthNames[monthNumber - 1];

    return '$periodLabel $monthName';
  }
}
