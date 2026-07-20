import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section_title.dart';
import '../viewmodels/check_status_view_model.dart';

class CheckStatusCard extends StatelessWidget {
  const CheckStatusCard({
    super.key,
    required this.viewModel,
  });

  final CheckStatusViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern("fa");

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionTitle(
            title: AppStrings.todayChecks,
            icon: Icons.account_balance_wallet_outlined,
          ),

          const SizedBox(height: AppSpacing.xl),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: viewModel.banks.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final bank = viewModel.banks[index];

              return Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Text(
                      bank.bankName,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.bodyLarge,
                    ),
                  ),
                  Text(
                    "${formatter.format(bank.totalAmount)} ${AppStrings.rial}",
                    style: AppTextStyles.amountSmall,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          const Divider(),

          const SizedBox(height: AppSpacing.lg),

          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  AppStrings.todayCommitments,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              Text(
                "${formatter.format(viewModel.totalTodayCommitments)} ${AppStrings.rial}",
                style: AppTextStyles.amountLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}