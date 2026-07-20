import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String? title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: AppSizes.iconXl,
              ),
            ),

            const SizedBox(
              height: AppSpacing.xxl,
            ),

            Text(
              title ?? AppStrings.noData,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3,
            ),

            if (message != null) ...[
              const SizedBox(
                height: AppSpacing.md,
              ),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],

            if (action != null) ...[
              const SizedBox(
                height: AppSpacing.xxl,
              ),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}