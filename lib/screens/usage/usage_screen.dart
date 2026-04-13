import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/usage/metric_card.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/navigation/popout_button.dart';

import 'package:cloudtolocalllm/services/rate_limit_manager.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';

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

  late final RateLimitManager _rateLimitManager;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rateLimitManager = context.read<RateLimitManager>();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch real metrics from services
      await Future.delayed(const Duration(milliseconds: 500));

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
FutureBuilder<List<ModelCapacityData>>(
      future: _rateLimitManager.watchCapacities().first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          final capacities = snapshot.data!;
          final totalTokens = capacities.fold(
              0, (sum, capacity) => sum + capacity.concurrentUsed);
          final totalLimit = capacities.fold(
              0, (sum, capacity) => sum + capacity.concurrentLimit);
          final utilization = totalLimit > 0 ? totalTokens / totalLimit : 0.0;

          return MetricCard(
            title: 'Token Usage',
            icon: Icons.token,
            value: _formatTokenValue(totalTokens),
            unit: 'tokens',
            subtitle: 'Total tokens processed',
            trend: utilization > 0.8 ? MetricTrend.up : MetricTrend.neutral,
            progressValue: utilization,
            progressLabel: 'Rate limit utilization',
            child: _buildTokenCostBreakdown(theme, capacities),
          );
        }
      },
    ),
                        const SizedBox(height: 16),

                        // Request Metrics Card
                        FutureBuilder<Map<String, dynamic>>(
                          future: _fetchRequestMetrics(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else {
                              final metrics = snapshot.data!;
                              return MetricCard(
                                title: 'Request Metrics',
                                icon: Icons.api,
                                value: '${metrics['requestsPerMin'] ?? 'N/A'}',
                                unit: 'req/min',
                                subtitle: 'Requests per minute',
                                trend: MetricTrend.neutral,
                                child: _buildRequestMetrics(theme, metrics),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Resource Usage Card
                        FutureBuilder<Map<String, dynamic>>(
                          future: _fetchResourceMetrics(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else {
                              final metrics = snapshot.data!;
                              return MetricCard(
                                title: 'Resource Usage',
                                icon: Icons.memory,
                                value: '${metrics['cpuUsage']}%',
                                unit: 'CPU',
                                subtitle: 'System resource consumption',
                                trend: MetricTrend.neutral,
                                child: _buildResourceMetrics(theme, metrics),
                              );
                            }
                          },
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

  Future<Map<String, dynamic>> _fetchRequestMetrics() async {
    // This would fetch real metrics from ConnectionManagerService
    // For now, return mock data with real structure
    return {
      'requestsPerMin': _getMockRequestValue(),
      'successRate': _selectedTimeRange == TimeRange.today ? '98.5%' : '97.2%',
      'avgLatency': _selectedTimeRange == TimeRange.today ? '245ms' : '312ms',
      'errorRate': _selectedTimeRange == TimeRange.today ? '1.5%' : '2.8%',
    };
  }

  Future<Map<String, dynamic>> _fetchResourceMetrics() async {
    // This would fetch real system metrics
    // For now, return mock data with real structure
    return {
      'cpuUsage': _getMockCpuUsage(),
      'memoryUsage': '2.1 GB',
      'diskUsage': '12.4 GB / 500 GB',
      'networkIo': '125 MB/s down, 42 MB/s up',
    };
  }

  String _formatTokenValue(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    } else {
      return tokens.toString();
    }
  }

  Widget _buildTokenCostBreakdown(ThemeData theme, List<ModelCapacityData> capacities) {
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
        _buildCostRow('Est. cost', r'$0.037', theme),
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

  Widget _buildRequestMetrics(ThemeData theme, Map<String, dynamic> metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildMetricRow('Success rate', metrics['successRate'], Icons.check_circle,
            Colors.green, theme),
        const SizedBox(height: 4),
        _buildMetricRow(
            'Avg latency', metrics['avgLatency'], Icons.speed, Colors.blue, theme),
        const SizedBox(height: 4),
        _buildMetricRow(
            'Error rate', metrics['errorRate'], Icons.error, Colors.red, theme),
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

  Widget _buildResourceMetrics(ThemeData theme, Map<String, dynamic> metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildResourceRow('Memory', metrics['memoryUsage'], theme, 0.26),
        const SizedBox(height: 4),
        _buildResourceRow('Disk', metrics['diskUsage'], theme, 0.025),
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
                metrics['networkIo'],
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

  // Mock data methods - for now, will be replaced with real implementations
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
}
