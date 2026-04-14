import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'trend_indicator.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.trendPercentage,
    this.iconColor,
    this.onTap,
    this.width,
  });

  final String label;
  final String value;
  final IconData icon;
  final double? trendPercentage;
  final Color? iconColor;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? AppColors.primary;
    final effectiveWidth = width ?? 160.0;

    return SizedBox(
      width: effectiveWidth,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: AppSpacing.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(icon, size: 20, color: effectiveColor),
                  ),
                  if (trendPercentage != null)
                    TrendIndicator(percentage: trendPercentage!),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(value, style: AppTypography.kpiValue),
              const SizedBox(height: 4),
              Text(label, style: AppTypography.kpiLabel),
            ],
          ),
        ),
      ),
    );
  }
}
