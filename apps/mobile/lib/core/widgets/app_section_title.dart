import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.trailing,
  });

  final String title;

  final IconData icon;

  final Color? iconColor;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppColors.secondary,
            size: 24,
          ),
        ),

        const SizedBox(width: AppSpacing.lg),

        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.right,
            style: AppTextStyles.h3,
          ),
        ),

        if (trailing != null) trailing!,
      ],
    );
  }
}