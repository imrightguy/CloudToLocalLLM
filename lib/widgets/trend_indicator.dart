import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum TrendDirection { up, down, neutral }

class TrendIndicator extends StatelessWidget {
  const TrendIndicator({
    super.key,
    required this.percentage,
    this.direction,
  });

  final double percentage;
  final TrendDirection? direction;

  @override
  Widget build(BuildContext context) {
    final dir = direction ??
        (percentage > 0
            ? TrendDirection.up
            : percentage < 0
                ? TrendDirection.down
                : TrendDirection.neutral);

    if (dir == TrendDirection.neutral) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove, size: 14, color: AppColors.textMuted),
          SizedBox(width: 2),
          Text(
            '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );
    }

    final isUp = dir == TrendDirection.up;
    final displayValue = percentage.abs().toStringAsFixed(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.trending_up : Icons.trending_down,
          size: 14,
          color: isUp ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 2),
        Text(
          '$displayValue%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isUp ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }
}
