import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../../domain/models/commitment_period.dart';
import '../providers/dashboard_provider.dart';

class CommitmentPeriodList extends ConsumerWidget {
  const CommitmentPeriodList({super.key, this.onPeriodTap});

  final ValueChanged<CommitmentPeriod>? onPeriodTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        final periods = summary.periods;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.black.withValues(alpha: 0.05),
                width: 0.8,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: periods.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'تعهدی برای دوره‌های آینده وجود ندارد',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 390),
                      child: ListView.separated(
                        shrinkWrap: true,
                        primary: false,
                        itemCount: periods.length,
                        itemBuilder: (context, index) {
                          return _CommitmentPeriodRow(
                            period: periods[index],
                            onTap: onPeriodTap,
                          );
                        },
                        separatorBuilder: (context, index) {
                          return const Divider(
                            height: 1,
                            thickness: 0.6,
                            color: Color(0x1A000000),
                          );
                        },
                      ),
                    ),
            ),
          ),
        );
      },
      loading: () {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      error: (error, stack) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.black.withValues(alpha: 0.05),
                width: 0.8,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'خطا در بارگذاری تعهدات آینده',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CommitmentPeriodRow extends StatelessWidget {
  const _CommitmentPeriodRow({required this.period, this.onTap});

  final CommitmentPeriod period;
  final ValueChanged<CommitmentPeriod>? onTap;

  @override
  Widget build(BuildContext context) {
    final amountText =
        '${NumberFormat.decimalPattern('en').format(period.totalAmount)} ریال';
    final periodRange = _formatJalaliRange(period.startDate, period.endDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap?.call(period),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: period.title),
                          TextSpan(
                            text: ' ($periodRange)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0x99000000),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تعداد تعهدات ${NumberFormat.decimalPattern('en').format(period.commitmentCount)}   •   جمع مبلغ $amountText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => onTap?.call(period),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                splashRadius: 16,
                icon: const Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
        ),
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

  final startMonthName = _jalaliMonthNames[start.month - 1];
  final endMonthName = _jalaliMonthNames[end.month - 1];

  return '${start.day} $startMonthName تا ${end.day} $endMonthName';
}
