import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.height,
    this.width,
    this.backgroundColor,
    this.borderRadius,
    this.elevation = true,
    this.onTap,
  });

  final Widget child;

  final EdgeInsetsGeometry? padding;

  final EdgeInsetsGeometry? margin;

  final double? height;

  final double? width;

  final Color? backgroundColor;

  final double? borderRadius;

  final bool elevation;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardHorizontal,
            vertical: AppSpacing.cardVertical,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.card,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSizes.radiusXl,
        ),
        boxShadow: elevation
            ? [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: AppSizes.cardBlur,
                  spreadRadius: AppSizes.cardSpread,
                  offset: const Offset(
                    0,
                    AppSizes.cardOffsetY,
                  ),
                ),
              ]
            : [],
      ),
      child: child,
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSizes.radiusXl,
        ),
        onTap: onTap,
        child: card,
      ),
    );
  }
}