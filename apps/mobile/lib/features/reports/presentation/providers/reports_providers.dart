import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../core/sync/sync_operation.dart';
import '../../../../core/sync/sync_queue_item.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../data/models/cheque.dart';
import '../../../../features/cheques/presentation/providers/active_cheques_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../features/settings/presentation/providers/app_preferences_provider.dart';
import '../../../../features/settings/presentation/providers/communication_settings_provider.dart';

const List<String> jalaliMonthNames = <String>[
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

class ReportChequeFilter {
  const ReportChequeFilter({
    this.companyId,
    this.bankAccountId,
    this.isRegisteredInSayad,
    this.fromDueDate,
    this.toDueDate,
    this.minAmountRial,
    this.jalaliYear,
    this.jalaliMonth,
    this.commitmentOnly = false,
    this.sortByAmountDesc = false,
  });

  final int? companyId;
  final int? bankAccountId;
  final bool? isRegisteredInSayad;
  final DateTime? fromDueDate;
  final DateTime? toDueDate;
  final int? minAmountRial;
  final int? jalaliYear;
  final int? jalaliMonth;
  final bool commitmentOnly;
  final bool sortByAmountDesc;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ReportChequeFilter &&
        other.companyId == companyId &&
        other.bankAccountId == bankAccountId &&
        other.isRegisteredInSayad == isRegisteredInSayad &&
        other.fromDueDate == fromDueDate &&
        other.toDueDate == toDueDate &&
        other.minAmountRial == minAmountRial &&
        other.jalaliYear == jalaliYear &&
        other.jalaliMonth == jalaliMonth &&
        other.commitmentOnly == commitmentOnly &&
        other.sortByAmountDesc == sortByAmountDesc;
  }

  @override
  int get hashCode => Object.hash(
    companyId,
    bankAccountId,
    isRegisteredInSayad,
    fromDueDate,
    toDueDate,
    minAmountRial,
    jalaliYear,
    jalaliMonth,
    commitmentOnly,
    sortByAmountDesc,
  );
}

class ReportChequeListData {
  const ReportChequeListData({
    required this.cheques,
    required this.companyNames,
    required this.bankAccountNames,
  });

  final List<Cheque> cheques;
  final Map<int, String> companyNames;
  final Map<int, String> bankAccountNames;
}

class CompanyPerformanceRow {
  const CompanyPerformanceRow({
    required this.companyId,
    required this.companyName,
    required this.chequeCount,
    required this.totalAmount,
    required this.registeredInSayadCount,
    required this.notRegisteredInSayadCount,
    required this.cancelledCount,
    required this.paidCount,
    required this.averageAmount,
    required this.nearestDueDate,
    required this.latestChequeDate,
  });

  final int companyId;
  final String companyName;
  final int chequeCount;
  final int totalAmount;
  final int registeredInSayadCount;
  final int notRegisteredInSayadCount;
  final int cancelledCount;
  final int paidCount;
  final double averageAmount;
  final DateTime? nearestDueDate;
  final DateTime? latestChequeDate;
}

class UpcomingCommitmentBucket {
  const UpcomingCommitmentBucket({
    required this.title,
    required this.start,
    required this.end,
    required this.chequeCount,
    required this.totalAmount,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final int chequeCount;
  final int totalAmount;
}

class BankAccountSummaryRow {
  const BankAccountSummaryRow({
    required this.bankAccountId,
    required this.bankName,
    required this.accountTitle,
    required this.chequeCount,
    required this.totalIssuedAmount,
    required this.upcomingAmount,
    required this.averageAmount,
  });

  final int bankAccountId;
  final String bankName;
  final String accountTitle;
  final int chequeCount;
  final int totalIssuedAmount;
  final int upcomingAmount;
  final double averageAmount;
}

class UnregisteredCompanyRank {
  const UnregisteredCompanyRank({
    required this.companyId,
    required this.companyName,
    required this.count,
  });

  final int companyId;
  final String companyName;
  final int count;
}

class SayadStatusSummary {
  const SayadStatusSummary({
    required this.registeredCount,
    required this.notRegisteredCount,
    required this.registrationPercentage,
    required this.topUnregisteredCompanies,
  });

  final int registeredCount;
  final int notRegisteredCount;
  final double registrationPercentage;
  final List<UnregisteredCompanyRank> topUnregisteredCompanies;
}

class MonthlyCommitmentRow {
  const MonthlyCommitmentRow({
    required this.jalaliYear,
    required this.jalaliMonth,
    required this.chequeCount,
    required this.totalAmount,
    required this.maxDailyCommitment,
    required this.minDailyCommitment,
  });

  final int jalaliYear;
  final int jalaliMonth;
  final int chequeCount;
  final int totalAmount;
  final int maxDailyCommitment;
  final int minDailyCommitment;

  String get monthTitle => '${jalaliMonthNames[jalaliMonth - 1]} $jalaliYear';
}

class ActivityReportSummary {
  const ActivityReportSummary({
    required this.createdToday,
    required this.updatedToday,
    required this.deletedToday,
    required this.syncedToday,
    required this.failedSynchronizations,
  });

  final int createdToday;
  final int updatedToday;
  final int deletedToday;
  final int syncedToday;
  final int failedSynchronizations;
}

final reportFilteredChequesProvider =
    FutureProvider.family<ReportChequeListData, ReportChequeFilter>((
      ref,
      filter,
    ) async {
      final lookup = await ref.watch(activeChequeLookupProvider.future);
      final filtered = _applyFilter(lookup.cheques, filter);

      return ReportChequeListData(
        cheques: filtered,
        companyNames: lookup.companyNames,
        bankAccountNames: lookup.bankAccountNames,
      );
    });

final companyPerformanceReportProvider =
    FutureProvider<List<CompanyPerformanceRow>>((ref) async {
      final lookup = await ref.watch(activeChequeLookupProvider.future);

      final grouped = <int, _CompanyAggregate>{};
      for (final cheque in lookup.cheques) {
        final aggregate = grouped.putIfAbsent(
          cheque.companyId,
          () => _CompanyAggregate(companyId: cheque.companyId),
        );
        aggregate.cheques.add(cheque);
      }

      final rows =
          grouped.values
              .map((aggregate) {
                final cheques = aggregate.cheques;
                final totalAmount = cheques.fold<int>(
                  0,
                  (sum, cheque) => sum + cheque.amountRial,
                );
                final registeredInSayadCount = cheques
                    .where((cheque) => cheque.isRegisteredInSayad)
                    .length;
                final notRegisteredInSayadCount =
                    cheques.length - registeredInSayadCount;
                final cancelledCount = cheques
                    .where((cheque) => cheque.status == ChequeStatus.cancelled)
                    .length;
                final paidCount = cheques
                    .where((cheque) => cheque.status == ChequeStatus.registered)
                    .length;

                DateTime? nearestDueDate;
                for (final cheque in cheques) {
                  if (cheque.status == ChequeStatus.cancelled) {
                    continue;
                  }
                  if (nearestDueDate == null ||
                      cheque.dueDate.isBefore(nearestDueDate)) {
                    nearestDueDate = cheque.dueDate;
                  }
                }

                DateTime? latestChequeDate;
                for (final cheque in cheques) {
                  if (latestChequeDate == null ||
                      cheque.issueDate.isAfter(latestChequeDate)) {
                    latestChequeDate = cheque.issueDate;
                  }
                }

                return CompanyPerformanceRow(
                  companyId: aggregate.companyId,
                  companyName: lookup.companyNames[aggregate.companyId] ?? '—',
                  chequeCount: cheques.length,
                  totalAmount: totalAmount,
                  registeredInSayadCount: registeredInSayadCount,
                  notRegisteredInSayadCount: notRegisteredInSayadCount,
                  cancelledCount: cancelledCount,
                  paidCount: paidCount,
                  averageAmount: cheques.isEmpty
                      ? 0
                      : totalAmount / cheques.length,
                  nearestDueDate: nearestDueDate,
                  latestChequeDate: latestChequeDate,
                );
              })
              .toList(growable: false)
            ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

      return rows;
    });

final upcomingCommitmentsReportProvider =
    FutureProvider<List<UpcomingCommitmentBucket>>((ref) async {
      final cheques = await ref.watch(activeChequesProvider.future);
      final eligible = commitmentEligibleCheques(cheques);

      final startOfToday = _dayStart(DateTime.now());
      final startOfTomorrow = startOfToday.add(const Duration(days: 1));
      final startOfDayAfterTomorrow = startOfToday.add(const Duration(days: 2));
      final startOfDay8 = startOfToday.add(const Duration(days: 8));
      final startOfDay31 = startOfToday.add(const Duration(days: 31));

      return <UpcomingCommitmentBucket>[
        _buildUpcomingBucket(
          title: 'امروز',
          cheques: eligible,
          start: startOfToday,
          end: startOfTomorrow,
        ),
        _buildUpcomingBucket(
          title: 'فردا',
          cheques: eligible,
          start: startOfTomorrow,
          end: startOfDayAfterTomorrow,
        ),
        _buildUpcomingBucket(
          title: '۷ روز آینده',
          cheques: eligible,
          start: startOfDayAfterTomorrow,
          end: startOfDay8,
        ),
        _buildUpcomingBucket(
          title: '۳۰ روز آینده',
          cheques: eligible,
          start: startOfDay8,
          end: startOfDay31,
        ),
      ];
    });
final bankAccountSummaryReportProvider =
    FutureProvider<List<BankAccountSummaryRow>>((ref) async {
      final lookup = await ref.watch(activeChequeLookupProvider.future);
      final today = _dayStart(DateTime.now());

      final grouped = <int, _BankAggregate>{};
      for (final cheque in lookup.cheques) {
        final bank = lookup.bankAccountsById[cheque.bankAccountId];
        final aggregate = grouped.putIfAbsent(
          cheque.bankAccountId,
          () => _BankAggregate(
            bankAccountId: cheque.bankAccountId,
            bankName: bank?.bankName ?? '—',
            accountTitle: bank?.accountTitle ?? '—',
          ),
        );

        aggregate.totalIssuedAmount += cheque.amountRial;
        aggregate.chequeCount += 1;

        if (cheque.status != ChequeStatus.cancelled &&
            !cheque.dueDate.isBefore(today)) {
          aggregate.upcomingAmount += cheque.amountRial;
        }
      }

      final rows =
          grouped.values
              .map((aggregate) {
                return BankAccountSummaryRow(
                  bankAccountId: aggregate.bankAccountId,
                  bankName: aggregate.bankName,
                  accountTitle: aggregate.accountTitle,
                  chequeCount: aggregate.chequeCount,
                  totalIssuedAmount: aggregate.totalIssuedAmount,
                  upcomingAmount: aggregate.upcomingAmount,
                  averageAmount: aggregate.chequeCount == 0
                      ? 0
                      : aggregate.totalIssuedAmount / aggregate.chequeCount,
                );
              })
              .toList(growable: false)
            ..sort(
              (a, b) => b.totalIssuedAmount.compareTo(a.totalIssuedAmount),
            );

      return rows;
    });

final sayadStatusReportProvider = FutureProvider<SayadStatusSummary>((
  ref,
) async {
  final lookup = await ref.watch(activeChequeLookupProvider.future);

  var registeredCount = 0;
  var notRegisteredCount = 0;
  final unregisteredByCompany = <int, int>{};

  for (final cheque in lookup.cheques) {
    if (cheque.isRegisteredInSayad) {
      registeredCount += 1;
    } else {
      notRegisteredCount += 1;
      unregisteredByCompany.update(
        cheque.companyId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }

  final total = registeredCount + notRegisteredCount;
  final percentage = total == 0 ? 0.0 : (registeredCount / total) * 100.0;

  final top =
      unregisteredByCompany.entries
          .map(
            (entry) => UnregisteredCompanyRank(
              companyId: entry.key,
              companyName: lookup.companyNames[entry.key] ?? '—',
              count: entry.value,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => b.count.compareTo(a.count));

  return SayadStatusSummary(
    registeredCount: registeredCount,
    notRegisteredCount: notRegisteredCount,
    registrationPercentage: percentage,
    topUnregisteredCompanies: top.take(5).toList(growable: false),
  );
});

final monthlyCommitmentReportProvider =
    FutureProvider<List<MonthlyCommitmentRow>>((ref) async {
      final cheques = await ref.watch(activeChequesProvider.future);
      final eligible = commitmentEligibleCheques(cheques);

      final grouped = <int, _MonthlyAggregate>{};

      for (final cheque in eligible) {
        final dueJalali = Jalali.fromDateTime(cheque.dueDate);
        final monthKey = dueJalali.year * 100 + dueJalali.month;

        final aggregate = grouped.putIfAbsent(
          monthKey,
          () => _MonthlyAggregate(
            jalaliYear: dueJalali.year,
            jalaliMonth: dueJalali.month,
          ),
        );

        aggregate.totalAmount += cheque.amountRial;
        aggregate.chequeCount += 1;
        final dayKey = _dayStart(cheque.dueDate).millisecondsSinceEpoch;
        aggregate.dailyTotals.update(
          dayKey,
          (value) => value + cheque.amountRial,
          ifAbsent: () => cheque.amountRial,
        );
      }

      final rows =
          grouped.values
              .map((aggregate) {
                final dailyValues = aggregate.dailyTotals.values.toList(
                  growable: false,
                )..sort();

                return MonthlyCommitmentRow(
                  jalaliYear: aggregate.jalaliYear,
                  jalaliMonth: aggregate.jalaliMonth,
                  chequeCount: aggregate.chequeCount,
                  totalAmount: aggregate.totalAmount,
                  maxDailyCommitment: dailyValues.isEmpty
                      ? 0
                      : dailyValues.last,
                  minDailyCommitment: dailyValues.isEmpty
                      ? 0
                      : dailyValues.first,
                );
              })
              .toList(growable: false)
            ..sort((a, b) {
              final keyA = a.jalaliYear * 100 + a.jalaliMonth;
              final keyB = b.jalaliYear * 100 + b.jalaliMonth;
              return keyB.compareTo(keyA);
            });

      return rows;
    });

final largeAmountThresholdProvider = FutureProvider<int>((ref) async {
  final preferences = await ref.watch(appPreferencesProvider.future);
  return preferences.largeAmountThreshold;
});

final largeAmountChequesReportProvider = FutureProvider<List<Cheque>>((
  ref,
) async {
  final lookup = await ref.watch(activeChequeLookupProvider.future);
  final threshold = await ref.watch(largeAmountThresholdProvider.future);

  final filtered =
      lookup.cheques
          .where((cheque) => cheque.amountRial >= threshold)
          .toList(growable: false)
        ..sort((a, b) => b.amountRial.compareTo(a.amountRial));

  return filtered;
});

final activityReportProvider = FutureProvider<ActivityReportSummary>((
  ref,
) async {
  ref.watch(syncStateProvider);

  final lookup = await ref.watch(activeChequeLookupProvider.future);
  final queueRepo = ref.watch(syncQueueRepositoryProvider);
  final queueItems = await queueRepo.getAllItems();

  final todayStart = _dayStart(DateTime.now());
  final tomorrowStart = todayStart.add(const Duration(days: 1));

  var createdToday = 0;
  var updatedToday = 0;

  for (final cheque in lookup.cheques) {
    if (_inRange(cheque.createdAt, todayStart, tomorrowStart)) {
      createdToday += 1;
    }

    if (_inRange(cheque.updatedAt, todayStart, tomorrowStart) &&
        !_sameDay(cheque.createdAt, cheque.updatedAt)) {
      updatedToday += 1;
    }
  }

  var deletedToday = 0;
  var syncedToday = 0;
  var failedSynchronizations = 0;

  for (final item in queueItems) {
    if (item.status == SyncStatus.failed) {
      failedSynchronizations += 1;
    }

    if (item.entityType == syncEntityTypeCheque &&
        item.operation == SyncOperation.delete &&
        _inRange(item.createdAt, todayStart, tomorrowStart)) {
      deletedToday += 1;
    }

    if (item.status == SyncStatus.synced &&
        item.lastAttemptAt != null &&
        _inRange(item.lastAttemptAt!, todayStart, tomorrowStart)) {
      syncedToday += 1;
    }
  }

  return ActivityReportSummary(
    createdToday: createdToday,
    updatedToday: updatedToday,
    deletedToday: deletedToday,
    syncedToday: syncedToday,
    failedSynchronizations: failedSynchronizations,
  );
});

List<Cheque> _applyFilter(List<Cheque> input, ReportChequeFilter filter) {
  Iterable<Cheque> filtered = input;

  if (filter.companyId != null) {
    filtered = filtered.where((cheque) => cheque.companyId == filter.companyId);
  }

  if (filter.bankAccountId != null) {
    filtered = filtered.where(
      (cheque) => cheque.bankAccountId == filter.bankAccountId,
    );
  }

  if (filter.isRegisteredInSayad != null) {
    filtered = filtered.where(
      (cheque) => cheque.isRegisteredInSayad == filter.isRegisteredInSayad,
    );
  }

  if (filter.minAmountRial != null) {
    filtered = filtered.where(
      (cheque) => cheque.amountRial >= filter.minAmountRial!,
    );
  }

  if (filter.fromDueDate != null) {
    filtered = filtered.where(
      (cheque) => !cheque.dueDate.isBefore(filter.fromDueDate!),
    );
  }

  if (filter.toDueDate != null) {
    filtered = filtered.where(
      (cheque) => cheque.dueDate.isBefore(filter.toDueDate!),
    );
  }

  if (filter.jalaliYear != null && filter.jalaliMonth != null) {
    filtered = filtered.where((cheque) {
      final due = Jalali.fromDateTime(cheque.dueDate);
      return due.year == filter.jalaliYear && due.month == filter.jalaliMonth;
    });
  }

  if (filter.commitmentOnly) {
    filtered = filtered.where(
      (cheque) => cheque.status != ChequeStatus.cancelled,
    );
  }

  final list = filtered.toList(growable: false);

  if (filter.sortByAmountDesc) {
    list.sort((a, b) => b.amountRial.compareTo(a.amountRial));
    return list;
  }

  list.sort((a, b) {
    final due = a.dueDate.compareTo(b.dueDate);
    if (due != 0) {
      return due;
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return list;
}

UpcomingCommitmentBucket _buildUpcomingBucket({
  required String title,
  required List<Cheque> cheques,
  required DateTime start,
  required DateTime end,
}) {
  var count = 0;
  var total = 0;

  for (final cheque in cheques) {
    if (_inRange(cheque.dueDate, start, end)) {
      count += 1;
      total += cheque.amountRial;
    }
  }

  return UpcomingCommitmentBucket(
    title: title,
    start: start,
    end: end,
    chequeCount: count,
    totalAmount: total,
  );
}

DateTime _dayStart(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

bool _inRange(DateTime value, DateTime startInclusive, DateTime endExclusive) {
  return !value.isBefore(startInclusive) && value.isBefore(endExclusive);
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CompanyAggregate {
  _CompanyAggregate({required this.companyId});

  final int companyId;
  final List<Cheque> cheques = <Cheque>[];
}

class _BankAggregate {
  _BankAggregate({
    required this.bankAccountId,
    required this.bankName,
    required this.accountTitle,
  });

  final int bankAccountId;
  final String bankName;
  final String accountTitle;
  int chequeCount = 0;
  int totalIssuedAmount = 0;
  int upcomingAmount = 0;
}

class _MonthlyAggregate {
  _MonthlyAggregate({required this.jalaliYear, required this.jalaliMonth});

  final int jalaliYear;
  final int jalaliMonth;
  int chequeCount = 0;
  int totalAmount = 0;
  final Map<int, int> dailyTotals = <int, int>{};
}
