import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class BuildingPerfRow extends StatelessWidget {
  const BuildingPerfRow({
    super.key,
    required this.building,
    required this.rank,
    this.isLast = false,
    this.onTap,
  });

  final BuildingItem building;
  final int rank;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rate = building.occupancyRate;
    final ratePercent = rate * 100;

    Color barColor;
    if (ratePercent >= 90) {
      barColor = AppColors.success;
    } else if (ratePercent >= 70) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.error;
    }

    Color rankColor;
    if (rank == 1) {
      rankColor = AppColors.rankGold;
    } else if (rank == 2) {
      rankColor = AppColors.rankSilver;
    } else if (rank == 3) {
      rankColor = AppColors.rankBronze;
    } else {
      rankColor = AppColors.textMuted;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? rankColor.withValues(alpha: 0.15)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? rankColor : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.apartment, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    building.name,
                    style: AppTypography.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${building.occupiedUnits}/${building.totalUnits} unités',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${building.monthlyRevenue} \$/mois',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _OccupancyBar(rate: rate, color: barColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OccupancyBar extends StatelessWidget {
  const _OccupancyBar({required this.rate, required this.color});

  final double rate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        widthFactor: rate.clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class BuildingPerformanceCard extends StatelessWidget {
  const BuildingPerformanceCard({
    super.key,
    required this.buildings,
    this.maxBuildings = 5,
    this.onViewAll,
    this.onBuildingTap,
  });

  final List<BuildingItem> buildings;
  final int maxBuildings;
  final VoidCallback? onViewAll;
  final ValueChanged<BuildingItem>? onBuildingTap;

  @override
  Widget build(BuildContext context) {
    final sorted = List<BuildingItem>.from(buildings)
      ..sort((a, b) => b.monthlyRevenue.compareTo(a.monthlyRevenue));
    final display = sorted.take(maxBuildings).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Performance des immeubles',
                style: AppTypography.sectionHeader,
              ),
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    'Voir tout',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (display.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('Aucun immeuble', style: AppTypography.caption),
              ),
            )
          else
            ...display.asMap().entries.map((entry) {
              return BuildingPerfRow(
                building: entry.value,
                rank: entry.key + 1,
                isLast: entry.key == display.length - 1,
                onTap: onBuildingTap != null
                    ? () => onBuildingTap!(entry.value)
                    : null,
              );
            }),
        ],
      ),
    );
  }
}
