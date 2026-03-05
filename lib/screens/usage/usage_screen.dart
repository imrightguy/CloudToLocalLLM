import 'package:flutter/material.dart';

import '../../widgets/usage/metric_card.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/navigation/popout_button.dart';

enum TimeRange { today, week, month }

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  TimeRange _selectedTimeRange = TimeRange.today;
  bool _isLoading = false;
  String? _error;

  // TODO: Integrate with real data sources
  // - RateLimitManager for token usage metrics
  // - ConnectionManagerService for request metrics
  // - System metrics for resource usage

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: Fetch real metrics from services
      // await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadMetrics();
  }

  void _onTimeRangeChanged(Set<TimeRange> newSelection) {
    if (newSelection.isNotEmpty) {
      setState(() {
        _selectedTimeRange = newSelection.first;
      });
      _loadMetrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
          const PopOutButton(
            sectionName: 'usage',
            branchIndex: 5,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 200)
            : _error != null
                ? ErrorState(
                    message: _error!,
                    onRetry: _onRefresh,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time range selector
                        Center(
                          child: SegmentedButton<TimeRange>(
                            segments: const [
                              ButtonSegment(
                                value: TimeRange.today,
                                label: Text('Today'),
                                icon: Icon(Icons.today),
                              ),
                              ButtonSegment(
                                value: TimeRange.week,
                                label: Text('Week'),
                                icon: Icon(Icons.date_range),
                              ),
                              ButtonSegment(
                                value: TimeRange.month,
                                label: Text('Month'),
                                icon: Icon(Icons.calendar_month),
                              ),
                            ],
                            selected: {_selectedTimeRange},
                            onSelectionChanged: _onTimeRangeChanged,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Token Usage Card
                        MetricCard(
                          title: 'Token Usage',
                          icon: Icons.token,
                          value: _getMockTokenValue(),
                          unit: 'tokens',
                          subtitle: 'Total tokens processed',
                          trend: MetricTrend.up,
                          progressValue: _getMockTokenUsage(),
                          progressLabel: 'Rate limit utilization',
                          child: _buildTokenCostBreakdown(theme),
                        ),
                        const SizedBox(height: 16),

                        // Request Metrics Card
                        MetricCard(
                          title: 'Request Metrics',
                          icon: Icons.api,
                          value: _getMockRequestValue(),
                          unit: 'req/min',
                          subtitle: 'Requests per minute',
                          trend: MetricTrend.neutral,
                          child: _buildRequestMetrics(theme),
                        ),
                        const SizedBox(height: 16),

                        // Resource Usage Card
                        MetricCard(
                          title: 'Resource Usage',
                          icon: Icons.memory,
                          value: '${_getMockCpuUsage()}%',
                          unit: 'CPU',
                          subtitle: 'System resource consumption',
                          trend: MetricTrend.neutral,
                          child: _buildResourceMetrics(theme),
                        ),

                        const SizedBox(height: 24),

                        // Chart placeholders
                        _buildChartPlaceholder('Token Usage Over Time'),
                        const SizedBox(height: 16),
                        _buildChartPlaceholder('Request Volume'),
                        const SizedBox(height: 16),
                        _buildChartPlaceholder('Resource Trends'),
                      ],
                    ),
                  ),
      ),
    );
  }

  // Mock data methods - TODO: Replace with real data from services
  String _getMockTokenValue() {
    switch (_selectedTimeRange) {
      case TimeRange.today:
        return '124,583';
      case TimeRange.week:
        return '847,291';
      case TimeRange.month:
        return '3,521,847';
    }
  }

  double _getMockTokenUsage() {
    switch (_selectedTimeRange) {
      case TimeRange.today:
        return 0.65;
      case TimeRange.week:
        return 0.72;
      case TimeRange.month:
        return 0.58;
    }
  }

  String _getMockRequestValue() {
    switch (_selectedTimeRange) {
      case TimeRange.today:
        return '42';
      case TimeRange.week:
        return '38';
      case TimeRange.month:
        return '45';
    }
  }

  double _getMockCpuUsage() {
    // Simulate varying CPU usage
    return 35.0;
  }

  Widget _buildTokenCostBreakdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Cost Breakdown',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        _buildCostRow('Input tokens', '74,750', theme),
        _buildCostRow('Output tokens', '49,833', theme),
        _buildCostRow('Est. cost', '\$0.037', theme),
      ],
    );
  }

  Widget _buildCostRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestMetrics(ThemeData theme) {
    final successRate =
        _selectedTimeRange == TimeRange.today ? '98.5%' : '97.2%';
    final avgLatency =
        _selectedTimeRange == TimeRange.today ? '245ms' : '312ms';
    final errorRate = _selectedTimeRange == TimeRange.today ? '1.5%' : '2.8%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildMetricRow('Success rate', successRate, Icons.check_circle,
            Colors.green, theme),
        const SizedBox(height: 4),
        _buildMetricRow(
            'Avg latency', avgLatency, Icons.speed, Colors.blue, theme),
        const SizedBox(height: 4),
        _buildMetricRow(
            'Error rate', errorRate, Icons.error, Colors.red, theme),
      ],
    );
  }

  Widget _buildMetricRow(
      String label, String value, IconData icon, Color color, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildResourceMetrics(ThemeData theme) {
    final memoryUsage = '2.1 GB';
    final diskUsage = '12.4 GB / 500 GB';
    final networkIo = '125 MB/s down, 42 MB/s up';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildResourceRow('Memory', memoryUsage, theme, 0.26),
        const SizedBox(height: 4),
        _buildResourceRow('Disk', diskUsage, theme, 0.025),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                Icons.network_check,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'Network I/O',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Text(
                networkIo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResourceRow(
      String label, String value, ThemeData theme, double usage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              label == 'Memory' ? Icons.storage : Icons.folder,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (usage > 0) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: usage,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              usage >= 0.9
                  ? theme.colorScheme.error
                  : usage >= 0.7
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChartPlaceholder(String title) {
    final theme = Theme.of(context);

    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chart placeholder',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
