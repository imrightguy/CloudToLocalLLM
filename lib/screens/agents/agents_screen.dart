library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';
import '../../services/subagent_registry_service.dart';
// TODO: Uncomment when integrating with actual services
// import '../../services/agent_status_service.dart';
// import '../../services/agent_lifecycle_service.dart';

/// Screen displaying agent management with three tabs
///
/// Shows a tabbed view of:
/// - Registry: List of registered agents with status and actions
/// - Monitor: Live agent activity feed and performance metrics
/// - Config: Agent configuration forms
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen>
    with SingleTickerProviderStateMixin {
  /// Tab controller for the three tabs
  late TabController _tabController;

  /// Loading state indicator
  bool _isLoading = true;

  /// Error message if data loading fails
  String? _errorMessage;

  /// Registered agents list (for Registry tab)
  List<Subagent> _agents = [];

  /// Activity feed (for Monitor tab)
  List<AgentActivityEvent> _activityFeed = [];

  /// TODO: Integrate with actual services
  // final SubagentRegistryService _subagentRegistry = di.serviceLocator<SubagentRegistryService>();
  // final AgentStatusService _agentStatus = di.serviceLocator<AgentStatusService>();
  // final AgentLifecycleService _agentLifecycle = di.serviceLocator<AgentLifecycleService>();

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

  /// Load agents and activity data
  ///
  /// TODO: Replace with actual service integration
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // TODO: Replace with actual API calls
      // _agents = await _subagentRegistry.listSubagents();
      // _activityFeed = await _agentStatus.getActivityFeed();

      // Mock data for now
      _agents = _getMockAgents();
      _activityFeed = _getMockActivityFeed();

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

  /// Get mock agents data for testing
  ///
  /// TODO: Remove this method when service integration is complete
  List<Subagent> _getMockAgents() {
    final now = DateTime.now();
    return [
      Subagent(
        subagentId: 'agent-zoidbot-001',
        agentId: 'zoidbot',
        label: 'Zoidbot',
        task: 'Front agent, talks to users, executes commands',
        status: SubagentStatus.running,
        createdAt: now.subtract(const Duration(hours: 2)),
        startedAt: now.subtract(const Duration(hours: 2)),
      ),
      Subagent(
        subagentId: 'agent-benjamin-001',
        agentId: 'benjamin',
        label: 'Benjamin',
        task: 'Reviewer agent, validates decisions',
        status: SubagentStatus.running,
        createdAt: now.subtract(const Duration(hours: 2)),
        startedAt: now.subtract(const Duration(hours: 2)),
      ),
      Subagent(
        subagentId: 'agent-harper-001',
        agentId: 'harper',
        label: 'Harper',
        task: 'Research agent, gathers context',
        status: SubagentStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      Subagent(
        subagentId: 'agent-coordinator-001',
        agentId: 'coordinator',
        label: 'Coordinator',
        task: 'Supervisor cron, orchestrates multi-agent tasks',
        status: SubagentStatus.running,
        createdAt: now.subtract(const Duration(days: 1)),
        startedAt: now.subtract(const Duration(days: 1)),
      ),
      Subagent(
        subagentId: 'agent-test-001',
        agentId: 'test-runner',
        label: 'Test Runner',
        task: 'Executes test suites',
        status: SubagentStatus.completed,
        createdAt: now.subtract(const Duration(hours: 1)),
        startedAt: now.subtract(const Duration(minutes: 45)),
        completedAt: now.subtract(const Duration(minutes: 15)),
      ),
      Subagent(
        subagentId: 'agent-failed-001',
        agentId: 'error-handler',
        label: 'Error Handler',
        task: 'Handles system errors',
        status: SubagentStatus.failed,
        createdAt: now.subtract(const Duration(minutes: 20)),
        errorMessage: 'Connection timeout',
      ),
    ];
  }

  /// Get mock activity feed data for testing
  ///
  /// TODO: Remove this method when service integration is complete
  List<AgentActivityEvent> _getMockActivityFeed() {
    final now = DateTime.now();
    return [
      AgentActivityEvent(
        agentId: 'zoidbot',
        agentName: 'Zoidbot',
        eventType: ActivityEventType.started,
        message: 'Agent started successfully',
        timestamp: now.subtract(const Duration(seconds: 30)),
        metrics: ActivityMetrics(
          cpuUsage: 12.5,
          memoryUsage: 256.0,
          uptime: Duration(hours: 2, minutes: 15),
        ),
      ),
      AgentActivityEvent(
        agentId: 'benjamin',
        agentName: 'Benjamin',
        eventType: ActivityEventType.taskCompleted,
        message: 'Review completed: APPROVED',
        timestamp: now.subtract(const Duration(minutes: 2)),
        metrics: ActivityMetrics(
          cpuUsage: 8.3,
          memoryUsage: 128.0,
          uptime: Duration(hours: 2, minutes: 13),
        ),
      ),
      AgentActivityEvent(
        agentId: 'harper',
        agentName: 'Harper',
        eventType: ActivityEventType.research,
        message: 'Searching context: "conscience decision history"',
        timestamp: now.subtract(const Duration(minutes: 5)),
        metrics: ActivityMetrics(
          cpuUsage: 15.7,
          memoryUsage: 192.0,
          uptime: Duration(minutes: 25),
        ),
      ),
      AgentActivityEvent(
        agentId: 'test-runner',
        agentName: 'Test Runner',
        eventType: ActivityEventType.stopped,
        message: 'Test suite completed: 42 passed, 0 failed',
        timestamp: now.subtract(const Duration(minutes: 15)),
        metrics: ActivityMetrics(
          cpuUsage: 0.0,
          memoryUsage: 64.0,
          uptime: Duration(minutes: 30),
        ),
      ),
      AgentActivityEvent(
        agentId: 'error-handler',
        agentName: 'Error Handler',
        eventType: ActivityEventType.crashed,
        message: 'Agent crashed: Connection timeout',
        timestamp: now.subtract(const Duration(minutes: 20)),
        metrics: ActivityMetrics(
          cpuUsage: 0.0,
          memoryUsage: 0.0,
          uptime: Duration(minutes: 10),
        ),
      ),
      AgentActivityEvent(
        agentId: 'coordinator',
        agentName: 'Coordinator',
        eventType: ActivityEventType.statusUpdate,
        message: 'Heartbeat: All systems operational',
        timestamp: now.subtract(const Duration(seconds: 45)),
        metrics: ActivityMetrics(
          cpuUsage: 5.2,
          memoryUsage: 96.0,
          uptime: Duration(days: 1, hours: 2),
        ),
      ),
    ];
  }

  /// View agent details
  void _viewAgentDetails(Subagent agent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(agent.label ?? agent.subagentId),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Agent ID', agent.subagentId),
              _detailRow('Parent ID', agent.agentId),
              if (agent.label != null) _detailRow('Label', agent.label!),
              if (agent.task != null) _detailRow('Task', agent.task!),
              _detailRow('Status', agent.status.name.toUpperCase()),
              _detailRow('Created', DateFormat('MMM d, HH:mm').format(agent.createdAt)),
              if (agent.startedAt != null)
                _detailRow('Started', DateFormat('MMM d, HH:mm').format(agent.startedAt!)),
              if (agent.completedAt != null)
                _detailRow('Completed', DateFormat('MMM d, HH:mm').format(agent.completedAt!)),
              if (agent.errorMessage != null)
                _detailRow('Error', agent.errorMessage!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build a detail row for the dialog
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Start agent after confirmation
  void _startAgent(Subagent agent) {
    // TODO: Implement actual agent start
    // await _agentLifecycle.startAgent(agent.subagentId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting agent ${agent.label ?? agent.subagentId}...'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // TODO: Implement undo
          },
        ),
      ),
    );
  }

  /// Stop agent after confirmation
  void _stopAgent(Subagent agent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Agent'),
        content: Text(
          'Are you sure you want to stop agent ${agent.label ?? agent.subagentId}?\n\n'
          'This will halt all current tasks and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement actual agent stop
              // await _agentLifecycle.stopAgent(agent.subagentId);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Agent ${agent.label ?? agent.subagentId} stopped'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      // TODO: Implement undo
                    },
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Registry'),
            Tab(text: 'Monitor'),
            Tab(text: 'Config'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh agents',
            onPressed: _isLoading ? null : _loadData,
          ),
          const PopOutButton(
            sectionName: 'agents',
            branchIndex: 7,
          ),
        ],
      ),
      body: RefreshableScreen(
        onRefresh: _loadData,
        errorMessage: _errorMessage,
        child: TabBarView(
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

  /// Build Registry tab content
  Widget _buildRegistryTab() {
    if (_isLoading) {
      return const LoadingSkeleton(
        itemCount: 5,
        height: 80,
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    if (_agents.isEmpty) {
      return const EmptyState(
        icon: Icons.smart_toy,
        title: 'No Agents',
        message: 'No agents are currently registered.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _agents.length,
      itemBuilder: (context, index) {
        final agent = _agents[index];
        return _AgentCard(
          agent: agent,
          viewDetails: _viewAgentDetails,
          startAgent: _startAgent,
          stopAgent: _stopAgent,
        );
      },
    );
  }

  /// Build Monitor tab content
  Widget _buildMonitorTab() {
    if (_isLoading) {
      return const LoadingSkeleton(
        itemCount: 5,
        height: 80,
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    if (_activityFeed.isEmpty) {
      return const EmptyState(
        icon: Icons.monitor_heart,
        title: 'No Activity',
        message: 'No agent activity has been recorded yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activityFeed.length,
      itemBuilder: (context, index) {
        final event = _activityFeed[index];
        return _ActivityEventCard(event: event);
      },
    );
  }

  /// Build Config tab content
  Widget _buildConfigTab() {
    if (_isLoading) {
      return const LoadingSkeleton(
        itemCount: 3,
        height: 120,
      );
    }

    // TODO: Implement actual agent configuration forms
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfigSection(
            title: 'Agent Settings',
            fields: [
              _ConfigField(
                label: 'Max Concurrent Agents',
                value: '10',
                type: ConfigFieldType.number,
              ),
              _ConfigField(
                label: 'Agent Timeout (seconds)',
                value: '300',
                type: ConfigFieldType.number,
              ),
              _ConfigField(
                label: 'Auto-restart on failure',
                value: 'true',
                type: ConfigFieldType.boolean,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ConfigSection(
            title: 'Behavior Configuration',
            fields: [
              _ConfigField(
                label: 'Log Level',
                value: 'info',
                type: ConfigFieldType.dropdown,
                options: ['debug', 'info', 'warning', 'error'],
              ),
              _ConfigField(
                label: 'Heartbeat Interval (seconds)',
                value: '30',
                type: ConfigFieldType.number,
              ),
              _ConfigField(
                label: 'Enable Metrics Collection',
                value: 'true',
                type: ConfigFieldType.boolean,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ConfigSection(
            title: 'Resource Limits',
            fields: [
              _ConfigField(
                label: 'Max Memory per Agent (MB)',
                value: '512',
                type: ConfigFieldType.number,
              ),
              _ConfigField(
                label: 'Max CPU Usage (%)',
                value: '80',
                type: ConfigFieldType.number,
              ),
              _ConfigField(
                label: 'Task Queue Size',
                value: '100',
                type: ConfigFieldType.number,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              // TODO: Implement save configuration
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuration saved')),
              );
            },
            child: const Text('Save Configuration'),
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a single agent in the registry
class _AgentCard extends StatelessWidget {
  final Subagent agent;
  final void Function(Subagent) viewDetails;
  final void Function(Subagent) startAgent;
  final void Function(Subagent) stopAgent;

  const _AgentCard({
    required this.agent,
    required this.viewDetails,
    required this.startAgent,
    required this.stopAgent,
  });

  /// Get status type from subagent status
  StatusType _getStatusType(SubagentStatus status) {
    switch (status) {
      case SubagentStatus.running:
        return StatusType.running;
      case SubagentStatus.completed:
        return StatusType.healthy;
      case SubagentStatus.pending:
        return StatusType.idle;
      case SubagentStatus.failed:
        return StatusType.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.label ?? agent.subagentId,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (agent.task != null)
                        Text(
                          agent.task!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                StatusBadge(
                  status: _getStatusType(agent.status),
                  label: agent.status.name.toUpperCase(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'ID: ${agent.subagentId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  tooltip: 'View details',
                  onPressed: () => viewDetails(agent),
                ),
                if (agent.status == SubagentStatus.pending ||
                    agent.status == SubagentStatus.failed)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 18),
                    tooltip: 'Start agent',
                    onPressed: () => startAgent(agent),
                  ),
                if (agent.status == SubagentStatus.running)
                  IconButton(
                    icon: const Icon(Icons.stop, size: 18),
                    tooltip: 'Stop agent',
                    onPressed: () => stopAgent(agent),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying an activity event
class _ActivityEventCard extends StatelessWidget {
  final AgentActivityEvent event;

  const _ActivityEventCard({required this.event});

  /// Get icon for event type
  IconData _getEventIcon(ActivityEventType type) {
    switch (type) {
      case ActivityEventType.started:
        return Icons.play_arrow;
      case ActivityEventType.stopped:
        return Icons.stop;
      case ActivityEventType.crashed:
        return Icons.error;
      case ActivityEventType.taskCompleted:
        return Icons.check_circle;
      case ActivityEventType.research:
        return Icons.search;
      case ActivityEventType.statusUpdate:
        return Icons.update;
    }
  }

  /// Get color for event type
  Color _getEventColor(ActivityEventType type, ThemeData theme) {
    switch (type) {
      case ActivityEventType.started:
        return Colors.green;
      case ActivityEventType.stopped:
        return Colors.grey;
      case ActivityEventType.crashed:
        return theme.colorScheme.error;
      case ActivityEventType.taskCompleted:
        return Colors.blue;
      case ActivityEventType.research:
        return Colors.purple;
      case ActivityEventType.statusUpdate:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getEventColor(event.eventType, theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          _getEventIcon(event.eventType),
          color: color,
        ),
        title: Text(event.agentName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.message),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.memory,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'CPU: ${event.metrics.cpuUsage.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.storage,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'Mem: ${event.metrics.memoryUsage.toStringAsFixed(0)} MB',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatUptime(event.metrics.uptime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          _formatTimestamp(event.timestamp),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// Format uptime duration
  String _formatUptime(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Format timestamp
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }
}

/// Configuration section widget
class _ConfigSection extends StatelessWidget {
  final String title;
  final List<_ConfigField> fields;

  const _ConfigSection({
    required this.title,
    required this.fields,
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
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...fields.map((field) => _ConfigFieldWidget(field: field)),
          ],
        ),
      ),
    );
  }
}

/// Configuration field widget
class _ConfigFieldWidget extends StatefulWidget {
  final _ConfigField field;

  const _ConfigFieldWidget({required this.field});

  @override
  State<_ConfigFieldWidget> createState() => _ConfigFieldWidgetState();
}

class _ConfigFieldWidgetState extends State<_ConfigFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.field.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = widget.field;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (field.type == ConfigFieldType.boolean)
            SwitchListTile(
              value: field.value.toLowerCase() == 'true',
              title: const Text('Enabled'),
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                // TODO: Implement state change
              },
            )
          else if (field.type == ConfigFieldType.dropdown &&
              field.options != null)
            DropdownButtonFormField<String>(
              initialValue: field.value,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: field.options!.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (value) {
                // TODO: Implement state change
              },
            )
          else
            TextField(
              controller: _controller,
              keyboardType: field.type == ConfigFieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                // TODO: Implement state change
              },
            ),
        ],
      ),
    );
  }
}

/// Configuration field data class
class _ConfigField {
  final String label;
  final String value;
  final ConfigFieldType type;
  final List<String>? options;

  _ConfigField({
    required this.label,
    required this.value,
    required this.type,
    this.options,
  });
}

/// Configuration field type enum
enum ConfigFieldType {
  text,
  number,
  boolean,
  dropdown,
}

/// Activity event type enum
enum ActivityEventType {
  started,
  stopped,
  crashed,
  taskCompleted,
  research,
  statusUpdate,
}

/// Activity event data class
class AgentActivityEvent {
  final String agentId;
  final String agentName;
  final ActivityEventType eventType;
  final String message;
  final DateTime timestamp;
  final ActivityMetrics metrics;

  AgentActivityEvent({
    required this.agentId,
    required this.agentName,
    required this.eventType,
    required this.message,
    required this.timestamp,
    required this.metrics,
  });
}

/// Activity metrics data class
class ActivityMetrics {
  final double cpuUsage;
  final double memoryUsage;
  final Duration uptime;

  ActivityMetrics({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.uptime,
  });
}
