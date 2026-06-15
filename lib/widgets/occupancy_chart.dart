import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/fr_dates.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class OccupancyChartCard extends StatelessWidget {
  const OccupancyChartCard({
    super.key,
    required this.data,
    this.currentRate,
  });

  final List<OccupancyDataPoint> data;
  final double? currentRate;

  @override
  Widget build(BuildContext context) {
    final displayRate = currentRate ?? (data.isNotEmpty ? data.last.rate : 0.0);

    Color badgeColor;
    if (displayRate >= 80) {
      badgeColor = AppColors.success;
    } else if (displayRate >= 60) {
      badgeColor = AppColors.warning;
    } else {
      badgeColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Taux d'occupation", style: AppTypography.sectionHeader),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${displayRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: data.length < 2
                ? const Center(
                    child: Text(
                      'Données insuffisantes',
                      style: AppTypography.caption,
                    ),
                  )
                : LineChart(_buildChartData(data)),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(List<OccupancyDataPoint> data) {
    const frenchMonths = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc',
    ];

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.rate);
    }).toList();

    final interval = data.length > 6 ? 2.0 : 1.0;

    return LineChartData(
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: AppColors.chartLine2,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.chartLine2.withValues(alpha: 0.15),
            applyCutOffY: true,
          ),
        ),
      ],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
              final monthIdx = data[idx].month - 1;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  frenchMonths[monthIdx.clamp(0, 11)],
                  style: AppTypography.chartAxisLabel,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 25,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}%',
                style: AppTypography.chartAxisLabel,
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        drawVerticalLine: false,
        drawHorizontalLine: true,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.border.withValues(alpha: 0.5),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 90,
            color: AppColors.warning,
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              labelResolver: (_) => 'Objectif 90%',
              alignment: Alignment.topRight,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.surface,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final idx = spot.x.toInt();
              if (idx < 0 || idx >= data.length) return null;
              final point = data[idx];
              return LineTooltipItem(
                '${point.rate.toStringAsFixed(1)}%\n${kFrenchMonths[point.month - 1]} ${point.year}',
                const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

class OccupancyDataPoint {
  const OccupancyDataPoint({
    required this.month,
    required this.year,
    required this.rate,
  });

  final int month;
  final int year;
  final double rate;

  factory OccupancyDataPoint.fromJson(Map<String, dynamic> json) {
    final dateStr = json['month'] as String? ?? '';
    final parts = dateStr.split('-');
    return OccupancyDataPoint(
      month: parts.length >= 2 ? int.tryParse(parts[1]) ?? 1 : 1,
      year: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 2026 : 2026,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
