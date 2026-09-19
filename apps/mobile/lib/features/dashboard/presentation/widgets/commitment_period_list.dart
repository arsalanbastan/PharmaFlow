import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../../../settings/presentation/providers/app_preferences_provider.dart';
import '../../domain/models/commitment_company_summary.dart';
import '../../domain/models/commitment_day_summary.dart';
import '../../domain/models/commitment_period.dart';
import '../providers/dashboard_provider.dart';
import 'dashboard_visuals.dart';

class CommitmentPeriodList extends ConsumerStatefulWidget {
  const CommitmentPeriodList({
    super.key,
    this.parentScrollController,
    this.fillAvailableHeight = false,
  });

  final ScrollController? parentScrollController;
  final bool fillAvailableHeight;

  @override
  ConsumerState<CommitmentPeriodList> createState() =>
      _CommitmentPeriodListState();
}

class _CommitmentPeriodListState extends ConsumerState<CommitmentPeriodList> {
  final Set<String> _expandedPeriods = <String>{};

  bool _handleOverscroll(OverscrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }

    final parentController = widget.parentScrollController;

    if (parentController == null ||
        !parentController.hasClients ||
        notification.overscroll == 0) {
      return false;
    }

    final position = parentController.position;

    final target = (parentController.offset + notification.overscroll)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if (target != parentController.offset) {
      parentController.jumpTo(target);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final settings = ref.watch(appPreferencesProvider).valueOrNull;
    final thresholds = DashboardAmountThresholds(
      green:
          settings?.thresholds.green ?? defaultDashboardAmountThresholds.green,
      orange:
          settings?.thresholds.orange ??
          defaultDashboardAmountThresholds.orange,
      red: settings?.thresholds.red ?? defaultDashboardAmountThresholds.red,
    );

    return summaryAsync.when(
      data: (summary) {
        final periods = summary.periods;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Card(
            elevation: 0.3,
            shadowColor: DashboardThemeColors.shadow,
            surfaceTintColor: Colors.transparent,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: DashboardThemeColors.border, width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: periods.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'تعهدی برای دوره‌های آینده وجود ندارد',
                        style: TextStyle(
                          fontSize: 13,
                          color: DashboardThemeColors.muted,
                        ),
                      ),
                    )
                  : SizedBox(
                      height: widget.fillAvailableHeight
                          ? double.infinity
                          : 330,
                      child: NotificationListener<OverscrollNotification>(
                        onNotification: _handleOverscroll,
                        child: ListView.separated(
                          itemCount: periods.length,
                          separatorBuilder: (context, index) {
                            return const Divider(height: 1, thickness: 0.6);
                          },
                          itemBuilder: (context, index) {
                            final period = periods[index];
                            final isExpanded = _expandedPeriods.contains(
                              period.title,
                            );

                            return _PeriodGroup(
                              period: period,
                              thresholds: thresholds,
                              expanded: isExpanded,
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedPeriods.remove(period.title);
                                  } else {
                                    _expandedPeriods.add(period.title);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
      loading: () {
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stack) {
        return const Text(
          'خطا در بارگذاری تعهدات آینده',
          style: TextStyle(color: DashboardThemeColors.muted),
        );
      },
    );
  }
}

class _PeriodGroup extends StatelessWidget {
  const _PeriodGroup({
    required this.period,
    required this.thresholds,
    required this.expanded,
    required this.onTap,
  });

  final CommitmentPeriod period;
  final DashboardAmountThresholds thresholds;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.decimalPattern('en').format(period.totalAmount);
    final amountColor = dashboardAmountColor(
      period.totalAmount,
      thresholds: thresholds,
    );
    final range = _formatJalaliRange(period.startDate, period.endDate);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: DashboardThemeColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border(top: BorderSide(color: amountColor, width: 4)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 54,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: period.title,
                                style: const TextStyle(
                                  color: DashboardThemeColors.ink,
                                ),
                              ),
                              TextSpan(
                                text: ' ($range)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: DashboardThemeColors.muted,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تعداد تعهدات ${period.commitmentCount}   •   جمع مبلغ $amount ریال',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: DashboardThemeColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: amountColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          _CommitmentDaysSection(period: period, thresholds: thresholds),
      ],
    );
  }
}

class _CommitmentDaysSection extends ConsumerStatefulWidget {
  const _CommitmentDaysSection({
    required this.period,
    required this.thresholds,
  });

  final CommitmentPeriod period;
  final DashboardAmountThresholds thresholds;

  @override
  ConsumerState<_CommitmentDaysSection> createState() =>
      _CommitmentDaysSectionState();
}

class _CommitmentDaysSectionState
    extends ConsumerState<_CommitmentDaysSection> {
  final Set<int> _expandedDays = <int>{};

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(
      commitmentDaysByPeriodProvider(
        CommitmentPeriodRange(
          startDate: widget.period.startDate,
          endDate: widget.period.endDate,
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: daysAsync.when(
        data: (days) {
          if (days.isEmpty) {
            return const Text(
              'در این بازه تعهدی ثبت نشده است',
              style: TextStyle(fontSize: 12, color: DashboardThemeColors.muted),
            );
          }

          return Column(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                _CommitmentDayRow(
                  day: days[i],
                  thresholds: widget.thresholds,
                  expanded: _expandedDays.contains(
                    days[i].date.millisecondsSinceEpoch,
                  ),
                  onTap: () {
                    final key = days[i].date.millisecondsSinceEpoch;
                    setState(() {
                      if (_expandedDays.contains(key)) {
                        _expandedDays.remove(key);
                      } else {
                        _expandedDays.add(key);
                      }
                    });
                  },
                ),
                if (i < days.length - 1)
                  const Divider(
                    height: 8,
                    thickness: 0.4,
                    color: Color(0x1A000000),
                  ),
              ],
            ],
          );
        },
        loading: () {
          return const SizedBox(
            height: 24,
            child: Center(
              child: SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        error: (error, stack) {
          return const Text(
            'خطا در بارگذاری روزهای تعهد',
            style: TextStyle(fontSize: 12, color: DashboardThemeColors.muted),
          );
        },
      ),
    );
  }
}

class _CommitmentDayRow extends StatelessWidget {
  const _CommitmentDayRow({
    required this.day,
    required this.thresholds,
    required this.expanded,
    required this.onTap,
  });

  final CommitmentDaySummary day;
  final DashboardAmountThresholds thresholds;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jDate = Jalali.fromDateTime(day.date);
    final dayLabel = '${jDate.day} ${_jalaliMonthNames[jDate.month - 1]}';
    final amount = NumberFormat.decimalPattern('en').format(day.totalAmount);
    final amountColor = dashboardAmountColor(
      day.totalAmount,
      thresholds: thresholds,
    );

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DashboardThemeColors.ink,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: amountColor,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'تعداد ${day.commitmentCount}   مبلغ $amount ریال',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 6),
          _CommitmentCompaniesSection(day: day),
        ],
      ],
    );
  }
}

class _CommitmentCompaniesSection extends ConsumerWidget {
  const _CommitmentCompaniesSection({required this.day});

  final CommitmentDaySummary day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayStart = day.date;
    final dayEnd = dayStart.add(const Duration(days: 1));

    final companiesAsync = ref.watch(
      commitmentCompaniesByDayProvider(
        CommitmentDayRange(dayStart: dayStart, dayEnd: dayEnd),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 2),
      child: companiesAsync.when(
        data: (companies) {
          if (companies.isEmpty) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'برای این روز تعهدی ثبت نشده است',
                style: TextStyle(
                  fontSize: 11.5,
                  color: DashboardThemeColors.muted,
                ),
              ),
            );
          }

          return Column(
            children: [
              for (var i = 0; i < companies.length; i++) ...[
                _CommitmentCompanyItem(company: companies[i]),
                if (i < companies.length - 1)
                  const Divider(
                    height: 10,
                    thickness: 0.4,
                    color: Color(0x14000000),
                  ),
              ],
            ],
          );
        },
        loading: () {
          return const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        error: (error, stack) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'خطا در بارگذاری شرکت‌ها',
              style: TextStyle(
                fontSize: 11.5,
                color: DashboardThemeColors.muted,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommitmentCompanyItem extends StatelessWidget {
  const _CommitmentCompanyItem({required this.company});

  final CommitmentCompanySummary company;

  @override
  Widget build(BuildContext context) {
    final totalAmount = NumberFormat.decimalPattern(
      'en',
    ).format(company.totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          company.companyName,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: DashboardThemeColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'جمع مبلغ $totalAmount ریال',
          style: const TextStyle(
            fontSize: 11.5,
            color: DashboardThemeColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < company.cheques.length; i++) ...[
          _CommitmentChequeItem(cheque: company.cheques[i]),
          if (i < company.cheques.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _CommitmentChequeItem extends StatelessWidget {
  const _CommitmentChequeItem({required this.cheque});

  final CommitmentChequeSummary cheque;

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.decimalPattern('en').format(cheque.amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DashboardThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'چک ${cheque.chequeNumber}',
            style: const TextStyle(
              fontSize: 11.5,
              color: DashboardThemeColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            cheque.bankAccount,
            style: const TextStyle(
              fontSize: 11.5,
              color: DashboardThemeColors.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$amount ریال',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: DashboardThemeColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

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

String _formatJalaliRange(DateTime startDate, DateTime endDate) {
  final start = Jalali.fromDateTime(startDate);
  final end = Jalali.fromDateTime(endDate);

  return '${start.day} ${_jalaliMonthNames[start.month - 1]} تا ${end.day} ${_jalaliMonthNames[end.month - 1]}';
}
