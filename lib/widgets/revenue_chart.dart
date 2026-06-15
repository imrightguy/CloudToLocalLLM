import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/fr_dates.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class RevenueChartCard extends StatefulWidget {
  const RevenueChartCard({
    super.key,
    required this.data,
    this.months = 12,
  });

  final List<RevenueDataPoint> data;
  final int months;

  @override
  State<RevenueChartCard> createState() => _RevenueChartCardState();
}

class _RevenueChartCardState extends State<RevenueChartCard> {
  int _selectedMonth = 6;

  @override
  Widget build(BuildContext context) {
    final displayData = widget.data.length > widget.months
        ? widget.data.sublist(widget.data.length - widget.months)
        : widget.data;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Revenus mensuels', style: AppTypography.sectionHeader),
              _buildPeriodToggle(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 220,
            child: displayData.length < 2
                ? const Center(
                    child: Text(
                      'Données insuffisantes',
                      style: AppTypography.caption,
                    ),
                  )
                : LineChart(
                    _buildChartData(displayData),
                    duration: const Duration(milliseconds: 500),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _periodChip('6 mois', 6),
          _periodChip('12 mois', 12),
        ],
      ),
    );
  }

  Widget _periodChip(String label, int months) {
    final isSelected = _selectedMonth == months;
    return GestureDetector(
      onTap: () => setState(() => _selectedMonth = months),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  LineChartData _buildChartData(List<RevenueDataPoint> data) {
    const frenchMonths = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc',
    ];

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.revenue.toDouble());
    }).toList();

    final interval = _selectedMonth <= 6 ? 1 : 2;

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: AppColors.chartLine1,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.chartLine1.withValues(alpha: 0.1),
          ),
        ),
      ],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval.toDouble(),
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
            reservedSize: 48,
            getTitlesWidget: (value, meta) {
              return Text(
                _formatCompact(value.toInt()),
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
        horizontalInterval: 1,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.border.withValues(alpha: 0.5),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
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
                '${point.revenue} \$\n${kFrenchMonths[point.month - 1]} ${point.year}',
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

  String _formatCompact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return '$value';
  }
}

class RevenueDataPoint {
  const RevenueDataPoint({
    required this.month,
    required this.year,
    required this.revenue,
  });

  final int month;
  final int year;
  final int revenue;

  factory RevenueDataPoint.fromJson(Map<String, dynamic> json) {
    final dateStr = json['month'] as String? ?? '';
    final parts = dateStr.split('-');
    return RevenueDataPoint(
      month: parts.length >= 2 ? int.tryParse(parts[1]) ?? 1 : 1,
      year: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 2026 : 2026,
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
    );
  }
}
