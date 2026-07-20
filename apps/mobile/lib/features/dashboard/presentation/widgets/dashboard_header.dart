import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userName,
    required this.pharmacyName,
    required this.todayDate,
    this.onNotificationTap,
    this.onProfileTap,
  });

  final String userName;
  final String pharmacyName;
  final String todayDate;

  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: AppSizes.avatarLg,
              height: AppSizes.avatarLg,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(
                  AppSizes.radiusCircle,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: AppSizes.iconLg,
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.lg),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  textDirection: TextDirection.rtl,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text:
                            "${AppStrings.greeting} $userName 👋",
                        style: AppTextStyles.h3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: AppSpacing.sm,
                ),

                Text(
                  todayDate,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodySmall,
                ),

                const SizedBox(
                  height: AppSpacing.md,
                ),

                Text(
                  pharmacyName,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.titleLarge,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          InkWell(
            onTap: onNotificationTap,
            borderRadius: BorderRadius.circular(
              AppSizes.radiusCircle,
            ),
            child: Container(
              width: AppSizes.avatarMd,
              height: AppSizes.avatarMd,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(
                  AppSizes.radiusCircle,
                ),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.icon,
                size: AppSizes.iconMd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}