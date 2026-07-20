import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class AppError extends StatelessWidget {
  const AppError({
    super.key,
    this.title,
    this.message,
    this.onRetry,
  });

  final String? title;

  final String? message;

  final VoidCallback? onRetry;

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
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: AppSizes.iconLg,
              ),
            ),

            const SizedBox(
              height: AppSpacing.xl,
            ),

            Text(
              title ?? "خطا",
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

            if (onRetry != null) ...[
              const SizedBox(
                height: AppSpacing.xxl,
              ),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  AppStrings.retry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}