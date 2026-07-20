import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

class DashboardActions extends StatelessWidget {
  const DashboardActions({
    super.key,
    this.onAddCheque,
    this.onCompanies,
    this.onBanks,
    this.onReports,
  });

  final VoidCallback? onAddCheque;
  final VoidCallback? onCompanies;
  final VoidCallback? onBanks;
  final VoidCallback? onReports;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.add_card_rounded,
              label: AppStrings.addCheque,
              onTap: onAddCheque,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ActionButton(
              icon: Icons.business_rounded,
              label: AppStrings.companies,
              onTap: onCompanies,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ActionButton(
              icon: Icons.account_balance_rounded,
              label: AppStrings.bankAccounts,
              onTap: onBanks,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ActionButton(
              icon: Icons.assessment_rounded,
              label: AppStrings.reports,
              onTap: onReports,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}