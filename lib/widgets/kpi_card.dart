import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'trend_indicator.dart';

class KpiCard extends StatefulWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.trendPercentage,
    this.iconColor,
    this.onTap,
    this.width,
    this.semanticLabel,
  });

  final String label;
  final String value;
  final IconData icon;
  final double? trendPercentage;
  final Color? iconColor;
  final VoidCallback? onTap;
  final double? width;

  /// Accessibility label announced by screen readers. Falls back to [label].
  final String? semanticLabel;

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.iconColor ?? AppColors.primary;
    final effectiveWidth = widget.width ?? 160.0;
    final interactive = widget.onTap != null;
    final highlight = _hovered && interactive;

    final decoration = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      border: Border.all(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.5)
            : AppColors.border,
      ),
      boxShadow: highlight ? [AppSpacing.elevationCardHover] : null,
    );

    return Semantics(
      button: interactive,
      label: widget.semanticLabel,
      child: SizedBox(
        width: effectiveWidth,
        child: MouseRegion(
          cursor:
              interactive ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: interactive ? (_) => _setHovered(true) : null,
          onExit: interactive ? (_) => _setHovered(false) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: decoration,
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
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
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Icon(widget.icon,
                                size: 20, color: effectiveColor),
                          ),
                          if (widget.trendPercentage != null)
                            TrendIndicator(percentage: widget.trendPercentage!),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(widget.value, style: AppTypography.kpiValue),
                      const SizedBox(height: 4),
                      Text(widget.label, style: AppTypography.kpiLabel),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
