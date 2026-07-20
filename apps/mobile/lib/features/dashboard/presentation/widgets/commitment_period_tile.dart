import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../viewmodels/financial_commitments_view_model.dart';
import 'bank_commitment_tile.dart';

class CommitmentPeriodTile extends StatelessWidget {
  const CommitmentPeriodTile({
    super.key,
    required this.period,
  });

  final CommitmentPeriodViewModel period;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern("fa");

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.none,
      ),

      childrenPadding: const EdgeInsets.only(
        bottom: AppSpacing.md,
      ),

      shape: const Border(),

      collapsedShape: const Border(),

      title: Text(
        period.title,
        textAlign: TextAlign.right,
        style: AppTextStyles.titleMedium,
      ),

      subtitle: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
        ),
        child: Text(
          "${formatter.format(period.totalAmount)} ${AppStrings.rial}",
          textAlign: TextAlign.right,
          style: AppTextStyles.bodySmall,
        ),
      ),

      children: period.banks
          .map(
            (bank) => BankCommitmentTile(
              bank: bank,
            ),
          )
          .toList(),
    );
  }
}