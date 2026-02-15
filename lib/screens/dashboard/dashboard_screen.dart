import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/agent_lifecycle_service.dart';
import '../../services/connection_manager_service.dart';
import 'agent_list_view.dart';

/// Main dashboard screen showing agent overview and system status
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final agentService = context.read<AgentLifecycleService>();
    final connService = context.read<ConnectionManagerService>();

    try {
      await agentService.refreshAgents();
      await connService.testConnection();
    } catch (e) {
      debugPrint('[Dashboard] Failed to refresh data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status Card
              _buildConnectionStatusCard(context),

              const SizedBox(height: 16),

              // Agent Overview Card
              _buildAgentOverviewCard(context),

              const SizedBox(height: 16),

              // Quick Actions Card
              _buildQuickActionsCard(context),

              const SizedBox(height: 16),

              // System Metrics Card
              _buildSystemMetricsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(BuildContext context) {
    return Consumer<ConnectionManagerService>(
      builder: (context, connService, child) {
        final isConnected = connService.isConnected;
        final isHealthy = connService.isGatewayHealthy();
        final gatewayStatus = connService.getGatewayStatus();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isHealthy ? Icons.cloud_done : Icons.cloud_off,
                      color: isHealthy ? Colors.green : Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OpenClaw Gateway',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            isConnected && isHealthy
                                ? 'Connected and Healthy'
                                : isConnected
                                    ? 'Connected - Issues Detected'
                                    : 'Disconnected',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isHealthy ? Colors.green : Colors.orange,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (!isHealthy)
                      ElevatedButton(
                        onPressed: _refreshData,
                        child: const Text('Reconnect'),
                      ),
                  ],
                ),
                if (gatewayStatus['lastError'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gatewayStatus['lastError'],
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Endpoint: ${gatewayStatus['endpoint']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (gatewayStatus['lastSuccessfulConnection'] != null) ...[
                  Text(
                    'Last connected: ${gatewayStatus['lastSuccessfulConnection']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgentOverviewCard(BuildContext context) {
    return Consumer<AgentLifecycleService>(
      builder: (context, agentService, child) {
        final agents = agentService.agents;
        final isLoading = agentService.isLoading;

        final runningCount = agents.where((a) => a.state == AgentLifecycleState.running).length;
        final idleCount = agents.where((a) => a.state == AgentLifecycleState.idle).length;
        const errorCount = 0; // agents.where((a) => a.state == AgentLifecycleState.error).length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Agent Overview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total',
                        value: '${agents.length}',
                        icon: Icons.apps,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Running',
                        value: '$runningCount',
                        icon: Icons.play_circle_filled,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Idle',
                        value: '$idleCount',
                        icon: Icons.pause_circle_outline,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AgentListView(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list),
                    label: const Text('View All Agents'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    return Consumer<ConnectionManagerService>(
      builder: (context, connService, child) {
        final isConnected = connService.isConnected;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.refresh, size: 18),
                      label: const Text('Test Connection'),
                      onPressed: isConnected
                          ? () async {
                              await connService.testConnection();
                              if (mounted) setState(() {});
                            }
                          : null,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.list, size: 18),
                      label: const Text('List Agents'),
                      onPressed: isConnected
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AgentListView(),
                                ),
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemMetricsCard(BuildContext context) {
    return Consumer<ConnectionManagerService>(
      builder: (context, connService, child) {
        final gatewayStatus = connService.getGatewayStatus();
        final healthStatus = gatewayStatus['healthStatus'] ?? 'unknown';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Metrics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _MetricRow(
                  label: 'Gateway Status',
                  value: _formatHealthStatus(healthStatus),
                  icon: _getHealthIcon(healthStatus),
                  iconColor: _getHealthColor(healthStatus),
                ),
                const SizedBox(height: 12),
                _MetricRow(
                  label: 'Connection',
                  value: connService.isConnected ? 'Active' : 'Inactive',
                  icon: connService.isConnected ? Icons.check_circle : Icons.cancel,
                  iconColor: connService.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 12),
                _MetricRow(
                  label: 'Gateway URL',
                  value: gatewayStatus['endpoint'] ?? 'Unknown',
                  icon: Icons.http,
                  iconColor: Colors.blue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatHealthStatus(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return 'Healthy';
      case 'unhealthy':
        return 'Unhealthy';
      case 'connecting':
        return 'Connecting...';
      case 'error':
        return 'Error';
      default:
        return 'Unknown';
    }
  }

  IconData _getHealthIcon(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Icons.check_circle;
      case 'unhealthy':
        return Icons.warning;
      case 'connecting':
        return Icons.sync;
      case 'error':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _getHealthColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Colors.green;
      case 'unhealthy':
        return Colors.orange;
      case 'connecting':
        return Colors.blue;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
