import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../viewmodels/financial_commitments_view_model.dart';
import 'company_commitment_tile.dart';

class BankCommitmentTile extends StatelessWidget {
  const BankCommitmentTile({
    super.key,
    required this.bank,
  });

  final BankCommitmentViewModel bank;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern("fa");

    return Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.lg,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.none,
        ),

        childrenPadding: const EdgeInsets.only(
          bottom: AppSpacing.sm,
        ),

        shape: const Border(),

        collapsedShape: const Border(),

        leading: const Icon(
          Icons.account_balance_rounded,
          color: AppColors.secondary,
        ),

        title: Text(
          bank.bankName,
          textAlign: TextAlign.right,
          style: AppTextStyles.titleSmall,
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xs,
          ),
          child: Text(
            "${formatter.format(bank.totalAmount)} ${AppStrings.rial}",
            textAlign: TextAlign.right,
            style: AppTextStyles.bodySmall,
          ),
        ),

        children: bank.companies
            .map(
              (company) => CompanyCommitmentTile(
                company: company,
              ),
            )
            .toList(),
      ),
    );
  }
}