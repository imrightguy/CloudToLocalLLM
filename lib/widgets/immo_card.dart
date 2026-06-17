import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum ImmoCardVariant { kpi, flow, stat, activity, building }

class ImmoCard extends StatelessWidget {
  const ImmoCard({
    super.key,
    required this.variant,
    this.child,
    this.onTap,
    this.width,
    this.minWidth,
    this.padding,
    this.accentColor,
    this.borderColor,
  });

  final ImmoCardVariant variant;
  final Widget? child;
  final VoidCallback? onTap;
  final double? width;
  final double? minWidth;
  final EdgeInsets? padding;
  final Color? accentColor;
  final Color? borderColor;

  EdgeInsets get _defaultPadding {
    switch (variant) {
      case ImmoCardVariant.kpi:
        return const EdgeInsets.all(AppSpacing.lg);
      case ImmoCardVariant.flow:
        return const EdgeInsets.all(AppSpacing.lg);
      case ImmoCardVariant.stat:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
      case ImmoCardVariant.activity:
        return const EdgeInsets.all(AppSpacing.lg);
      case ImmoCardVariant.building:
        return const EdgeInsets.all(AppSpacing.lg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? AppColors.border;

    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          onTap: onTap,
          child: Container(
            padding: padding ?? _defaultPadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: effectiveBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
