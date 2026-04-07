/// Screen for managing AI agents with monitoring and configuration
library;

import 'package:flutter/material.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';

// TODO: Uncomment when integrating with actual services
// import '../../services/subagent_registry_service.dart';
// import '../../services/agent_status_service.dart';
// import '../../di/locator.dart' as di;

/// Agent model for displaying in the registry
class Agent {
  final String id;
  final String name;
  final String description;
  final AgentStatus status;
  final int taskCount;
  final double avgLatency;
  final DateTime lastActive;

  const Agent({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    this.taskCount = 0,
    this.avgLatency = 0.0,
    required this.lastActive,
  });
}

/// Agent status enum
enum AgentStatus {
  online,
  offline,
  busy,
  error,
}

/// Activity event for monitoring
class ActivityEvent {
  final String agentId;
  final String agentName;
  final String action;
  final DateTime timestamp;
  final bool success;

  const ActivityEvent({
    required this.agentId,
    required this.agentName,
    required this.action,
    required this.timestamp,
    required this.success,
  });
}

/// Screen displaying agents management with three tabs
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<Agent> _agents = [];
  List<ActivityEvent> _activityFeed = [];

  // TODO: Integrate with actual services
  // final SubagentRegistryService _subagentRegistry =
  //     di.serviceLocator<SubagentRegistryService>();
  // final AgentStatusService _agentStatus = di.serviceLocator<AgentStatusService>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      // Mock agents data
      // TODO: Load from SubagentRegistryService to get real agent data
      _agents = [
        Agent(
          id: 'code-reviewer',
          name: 'Code Review Agent',
          description:
              'Analyzes pull requests for bugs, security issues, and best practices',
          status: AgentStatus.online,
          taskCount: 234,
          avgLatency: 2.8,
          lastActive: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        Agent(
          id: 'file-scanner',
          name: 'File Scanner Agent',
          description:
              'Scans directories for specific file patterns and security risks',
          status: AgentStatus.busy,
          taskCount: 567,
          avgLatency: 1.9,
          lastActive: DateTime.now().subtract(const Duration(seconds: 30)),
        ),
        Agent(
          id: 'doc-summarizer',
          name: 'Document Summarizer Agent',
          description:
              'Creates concise summaries of long documents and articles',
          status: AgentStatus.online,
          taskCount: 891,
          avgLatency: 0.8,
          lastActive: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        Agent(
          id: 'data-analyzer',
          name: 'Data Analysis Agent',
          description:
              'Performs statistical analysis and generates insights from datasets',
          status: AgentStatus.offline,
          taskCount: 123,
          avgLatency: 2.1,
          lastActive: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        Agent(
          id: 'backup-automation',
          name: 'Backup Automation Agent',
          description: 'Automates backup tasks and verifies data integrity',
          status: AgentStatus.online,
          taskCount: 456,
          avgLatency: 1.5,
          lastActive: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
        Agent(
          id: 'security-inspector',
          name: 'Security Inspector Agent',
          description: 'Performs security audits and vulnerability scans',
          status: AgentStatus.error,
          taskCount: 12,
          avgLatency: 5.2,
          lastActive: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
      ];

      // Mock activity feed
      final now = DateTime.now();
      _activityFeed = [
        ActivityEvent(
          agentId: 'doc-summarizer',
          agentName: 'Document Summarizer Agent',
          action: 'Completed task: Summarized project documentation',
          timestamp: now.subtract(const Duration(seconds: 45)),
          success: true,
        ),
        ActivityEvent(
          agentId: 'code-reviewer',
          agentName: 'Code Review Agent',
          action: 'Started task: Reviewing PR #234',
          timestamp: now.subtract(const Duration(minutes: 2)),
          success: true,
        ),
        ActivityEvent(
          agentId: 'file-scanner',
          agentName: 'File Scanner Agent',
          action: 'Completed task: Scanned /src directory',
          timestamp: now.subtract(const Duration(minutes: 5)),
          success: true,
        ),
        ActivityEvent(
          agentId: 'security-inspector',
          agentName: 'Security Inspector Agent',
          action: 'Task failed: Scan timeout',
          timestamp: now.subtract(const Duration(minutes: 15)),
          success: false,
        ),
        ActivityEvent(
          agentId: 'backup-automation',
          agentName: 'Backup Automation Agent',
          action: 'Completed task: Daily backup verified',
          timestamp: now.subtract(const Duration(minutes: 20)),
          success: true,
        ),
        ActivityEvent(
          agentId: 'data-analyzer',
          agentName: 'Data Analysis Agent',
          action: 'Completed task: Generated sales report',
          timestamp: now.subtract(const Duration(minutes: 35)),
          success: true,
        ),
        ActivityEvent(
          agentId: 'data-analyzer',
          agentName: 'Data Analysis Agent',
          action: 'Went offline for maintenance',
          timestamp: now.subtract(const Duration(hours: 2)),
          success: true,
        ),
      ];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load agents: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableScreen(
      onRefresh: _onRefresh,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agents'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add new agent - coming soon')),
                );
              },
              tooltip: 'Add Agent',
            ),
            PopOutButton(sectionName: 'agents', branchIndex: 7),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Registry', icon: Icon(Icons.people_outline)),
              Tab(text: 'Monitor', icon: Icon(Icons.monitor_heart)),
              Tab(text: 'Config', icon: Icon(Icons.settings)),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 200)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _onRefresh)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRegistryTab(),
                      _buildMonitorTab(),
                      _buildConfigTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRegistryTab() {
    if (_agents.isEmpty) {
      return const EmptyState(
        icon: Icons.people,
        title: 'No Agents Registered',
        message: 'Agents will appear here when registered',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _agents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final agent = _agents[index];
        return _buildAgentCard(agent);
      },
    );
  }

  Widget _buildAgentCard(Agent agent) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      _getStatusColor(agent.status).withValues(alpha: 0.1),
                  child: Icon(
                    _getStatusIcon(agent.status),
                    color: _getStatusColor(agent.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            agent.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            status: agent.status == AgentStatus.online
                                ? StatusType.active
                                : agent.status == AgentStatus.busy
                                    ? StatusType.running
                                    : agent.status == AgentStatus.offline
                                        ? StatusType.stopped
                                        : StatusType.error,
                            label: agent.status.name.toUpperCase(),
                            showIcon: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        agent.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showAgentMenu(agent);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStat(
                    Icons.check_circle, agent.taskCount.toString(), 'Tasks'),
                _buildStat(Icons.speed, '${agent.avgLatency}s', 'Avg Latency'),
                _buildStat(Icons.access_time,
                    _formatLastActive(agent.lastActive), 'Last Active'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }

  Widget _buildMonitorTab() {
    return Column(
      children: [
        // Summary cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSummaryCard(
                Icons.people,
                'Total Agents',
                '${_agents.length}',
                Colors.blue,
              ),
              _buildSummaryCard(
                Icons.check_circle,
                'Tasks Today',
                '${_agents.fold<int>(0, (sum, a) => sum + a.taskCount)}',
                Colors.green,
              ),
              _buildSummaryCard(
                Icons.speed,
                'Avg Latency',
                '${(_agents.fold<double>(0, (sum, a) => sum + a.avgLatency) / _agents.length).toStringAsFixed(1)}s',
                Colors.orange,
              ),
              _buildSummaryCard(
                Icons.error,
                'Errors',
                '${_agents.where((a) => a.status == AgentStatus.error).length}',
                Colors.red,
              ),
            ],
          ),
        ),
        const Divider(),
        // Activity feed
        Expanded(
          child: _activityFeed.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No Recent Activity',
                  message: 'Agent activity will appear here',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activityFeed.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = _activityFeed[index];
                    return _buildActivityCard(event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      IconData icon, String title, String value, Color color) {
    return Card(
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityEvent event) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: event.success
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            event.success ? Icons.check : Icons.close,
            color: event.success ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(event.action),
        subtitle:
            Text('${_formatTimestamp(event.timestamp)} • ${event.agentName}'),
        trailing: event.success
            ? null
            : Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, size: 20),
                      const SizedBox(width: 8),
                      Text('Agent Pool Settings',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Auto-scale agents'),
                    subtitle:
                        const Text('Automatically add agents based on load'),
                    value: true,
                    onChanged: (value) {},
                  ),
                  ListTile(
                    title: const Text('Min agents'),
                    subtitle: const Text('Minimum number of active agents'),
                    trailing: const Text('2'),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Max agents'),
                    subtitle: const Text('Maximum number of concurrent agents'),
                    trailing: const Text('10'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 20),
                      const SizedBox(width: 8),
                      Text('Timeout Settings',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Request timeout'),
                    subtitle:
                        const Text('Maximum time to wait for agent response'),
                    trailing: const Text('30s'),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Queue timeout'),
                    subtitle:
                        const Text('Maximum time in queue before rejection'),
                    trailing: const Text('60s'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAgentMenu(Agent agent) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(agent.status == AgentStatus.online
                  ? Icons.pause
                  : Icons.play_arrow),
              title: Text(agent.status == AgentStatus.online
                  ? 'Pause Agent'
                  : 'Resume Agent'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          '${agent.name}: ${agent.status == AgentStatus.online ? 'Paused' : 'Resumed'}')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Restart Agent'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${agent.name}: Restarting...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Configuration'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Agent configuration - coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove Agent'),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveAgent(agent);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveAgent(Agent agent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Agent'),
        content: Text('Are you sure you want to remove ${agent.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _agents.removeWhere((a) => a.id == agent.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${agent.name} removed')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(AgentStatus status) {
    switch (status) {
      case AgentStatus.online:
        return Icons.check_circle;
      case AgentStatus.offline:
        return Icons.offline_bolt;
      case AgentStatus.busy:
        return Icons.sync;
      case AgentStatus.error:
        return Icons.error;
    }
  }

  Color _getStatusColor(AgentStatus status) {
    switch (status) {
      case AgentStatus.online:
        return Colors.green;
      case AgentStatus.offline:
        return Colors.grey;
      case AgentStatus.busy:
        return Colors.blue;
      case AgentStatus.error:
        return Colors.red;
    }
  }

  String _formatLastActive(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
