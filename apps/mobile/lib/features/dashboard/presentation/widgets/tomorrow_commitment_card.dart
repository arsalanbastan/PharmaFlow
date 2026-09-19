import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../settings/presentation/providers/app_preferences_provider.dart';
import '../providers/dashboard_provider.dart';
import 'dashboard_visuals.dart';

class TomorrowCommitmentCard extends ConsumerWidget {
  const TomorrowCommitmentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Directionality(
      textDirection: TextDirection.rtl,

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              const Text(
                'تعهدات فردا',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: DashboardThemeColors.ink,
                ),
              ),

              const SizedBox(height: 8),

              summaryAsync.when(
                data: (summary) {
                  final commitments = summary.tomorrow.bankCommitments;

                  if (commitments.isEmpty) {
                    return const Text(
                      'فردا تعهد مالی ثبت نشده است',
                      style: TextStyle(
                        fontSize: 13,
                        color: DashboardThemeColors.muted,
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (var i = 0; i < commitments.length; i++) ...[
                        SizedBox(
                          height: 30,
                          child: _BankCommitmentRow(
                            bankName: commitments[i].bankName,
                            amount: NumberFormat.decimalPattern(
                              'en',
                            ).format(commitments[i].amount),
                            amountColor: dashboardAmountColor(
                              commitments[i].amount,
                              thresholds: thresholds,
                            ),
                          ),
                        ),
                        if (i < commitments.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Divider(
                              height: 1,
                              thickness: 0.6,
                              color: Color(0x1A000000),
                            ),
                          ),
                      ],
                    ],
                  );
                },
                loading: () {
                  return const SizedBox(
                    height: 30,
                    child: Center(
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                error: (error, stack) {
                  return const Text(
                    'خطا در بارگذاری تعهدات فردا',
                    style: TextStyle(
                      fontSize: 12,
                      color: DashboardThemeColors.muted,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankCommitmentRow extends StatelessWidget {
  const _BankCommitmentRow({
    required this.bankName,
    required this.amount,
    required this.amountColor,
  });

  final String bankName;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 16,
                color: amountColor,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  bankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: DashboardThemeColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Text(
          '$amount ریال',
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}
