import 'package:flutter/material.dart';

enum MetricTrend { up, down, neutral }

class MetricCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final String? subtitle;
  final String? unit;
  final MetricTrend? trend;
  final Widget? child;
  final double? progressValue; // 0.0 to 1.0 for utilization bar
  final String? progressLabel;

  const MetricCard({
    required this.title,
    required this.icon,
    required this.value,
    this.subtitle,
    this.unit,
    this.trend,
    this.child,
    this.progressValue,
    this.progressLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (trend != null) _buildTrendIcon(context, trend!),
              ],
            ),
            const SizedBox(height: 16),

            // Main value display
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),

            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],

            // Progress bar for utilization
            if (progressValue != null) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (progressLabel != null)
                    Text(
                      progressLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progressValue!.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressValue! >= 0.9
                          ? theme.colorScheme.error
                          : progressValue! >= 0.7
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],

            // Custom content
            if (child != null) ...[
              const SizedBox(height: 16),
              child!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIcon(BuildContext context, MetricTrend trend) {
    final theme = Theme.of(context);
    IconData iconData;
    Color color;

    switch (trend) {
      case MetricTrend.up:
        iconData = Icons.trending_up;
        color = Colors.green;
        break;
      case MetricTrend.down:
        iconData = Icons.trending_down;
        color = Colors.red;
        break;
      case MetricTrend.neutral:
        iconData = Icons.trending_flat;
        color = theme.colorScheme.onSurface.withValues(alpha: 0.6);
        break;
    }

    return Icon(
      iconData,
      size: 20,
      color: color,
    );
  }
}
