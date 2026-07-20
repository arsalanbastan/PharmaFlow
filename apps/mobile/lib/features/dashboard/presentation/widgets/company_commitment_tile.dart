import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../viewmodels/financial_commitments_view_model.dart';

class CompanyCommitmentTile extends StatelessWidget {
  const CompanyCommitmentTile({
    super.key,
    required this.company,
  });

  final CompanyCommitmentViewModel company;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern("fa");

    return Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.xxl,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Icon(
            Icons.circle,
            size: 8,
          ),

          const SizedBox(
            width: AppSpacing.md,
          ),

          Expanded(
            child: Text(
              company.companyName,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium,
            ),
          ),

          Text(
            "${formatter.format(company.totalAmount)} ${AppStrings.rial}",
            style: AppTextStyles.amountSmall,
          ),
        ],
      ),
    );
  }
}