import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/agent_lifecycle_service.dart';

/// Agent List View - Shows all available agents with their status
class AgentListView extends StatefulWidget {
  const AgentListView({super.key});

  @override
  State<AgentListView> createState() => _AgentListViewState();
}

class _AgentListViewState extends State<AgentListView> {
  @override
  void initState() {
    super.initState();
    // Load agents when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAgents();
    });
  }

  Future<void> _loadAgents() async {
    final service = context.read<AgentLifecycleService>();
    try {
      await service.refreshAgents();
    } catch (e) {
      debugPrint('[AgentListView] Failed to load agents: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
        leading: BackButton(
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: Consumer<AgentLifecycleService>(
        builder: (context, service, child) {
          if (service.isLoading && service.agents.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!service.isReady) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Not Connected to OpenClaw Gateway',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.lastError ?? 'Connection required',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadAgents,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final agents = service.agents;

          if (agents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.smart_toy,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Agents Found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No agents are configured in OpenClaw Gateway',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadAgents,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadAgents,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return _AgentListTile(
                  agent: agent,
                  onRefresh: _loadAgents,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Consumer<AgentLifecycleService>(
        builder: (context, service, child) {
          return FloatingActionButton.extended(
            onPressed: service.isLoading ? null : _loadAgents,
            icon: service.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Refresh'),
          );
        },
      ),
    );
  }
}

class _AgentListTile extends StatelessWidget {
  final AgentInfo agent;
  final VoidCallback onRefresh;

  const _AgentListTile({
    required this.agent,
    required this.onRefresh,
  });

  Color _getStatusColor(AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return Colors.grey;
      case AgentLifecycleState.starting:
        return Colors.orange;
      case AgentLifecycleState.running:
        return Colors.green;
      case AgentLifecycleState.stopping:
        return Colors.orange.shade300;
      case AgentLifecycleState.error:
        return Colors.red;
      case AgentLifecycleState.offline:
        return Colors.grey.shade400;
    }
  }

  IconData _getStatusIcon(AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return Icons.pause_circle_outline;
      case AgentLifecycleState.starting:
        return Icons.play_circle_outline;
      case AgentLifecycleState.running:
        return Icons.play_circle_filled;
      case AgentLifecycleState.stopping:
        return Icons.stop_circle;
      case AgentLifecycleState.error:
        return Icons.error_outline;
      case AgentLifecycleState.offline:
        return Icons.cloud_off;
    }
  }

  String _getStatusText(AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return 'Idle';
      case AgentLifecycleState.starting:
        return 'Starting...';
      case AgentLifecycleState.running:
        return 'Running';
      case AgentLifecycleState.stopping:
        return 'Stopping...';
      case AgentLifecycleState.error:
        return 'Error';
      case AgentLifecycleState.offline:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(agent.state);
    final statusIcon = _getStatusIcon(agent.state);
    final statusText = _getStatusText(agent.state);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          agent.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${agent.type}'),
            if (agent.activity != null) Text(agent.activity!),
            if (agent.errorMessage != null)
              Text(
                agent.errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
          ],
        ),
        trailing: Chip(
          label: Text(
            statusText,
            style: TextStyle(color: statusColor),
          ),
          backgroundColor: statusColor.withValues(alpha: 0.1),
        ),
        isThreeLine: agent.activity != null || agent.errorMessage != null,
        onTap: () {
          // Navigate to agent detail screen
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => _AgentDetailScreen(agent: agent),
                ),
              )
              .then((_) => onRefresh());
        },
      ),
    );
  }
}

/// Agent Detail Screen - Shows detailed information about an agent
class _AgentDetailScreen extends StatefulWidget {
  final AgentInfo agent;

  const _AgentDetailScreen({required this.agent});

  @override
  State<_AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<_AgentDetailScreen> {
  bool _isOperating = false;

  Future<void> _startAgent() async {
    setState(() => _isOperating = true);
    final service = context.read<AgentLifecycleService>();
    final result = await service.startAgent(widget.agent.id);
    setState(() => _isOperating = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Unknown error'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _stopAgent() async {
    setState(() => _isOperating = true);
    final service = context.read<AgentLifecycleService>();
    final result = await service.stopAgent(widget.agent.id);
    setState(() => _isOperating = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Unknown error'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _restartAgent() async {
    setState(() => _isOperating = true);
    final service = context.read<AgentLifecycleService>();
    final result = await service.restartAgent(widget.agent.id);
    setState(() => _isOperating = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Unknown error'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentLifecycleService>(
      builder: (context, service, child) {
        final currentAgent = service.getAgent(widget.agent.id) ?? widget.agent;

        return Scaffold(
          appBar: AppBar(
            title: Text(currentAgent.name),
            leading: BackButton(
              onPressed: () {
                if (GoRouter.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go('/agents');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isOperating
                    ? null
                    : () async {
                        await service.getAgentStatus(currentAgent.id);
                        if (mounted) setState(() {});
                      },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(currentAgent.state),
                            color: _getStatusColor(currentAgent.state),
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                                Text(
                                  _getStatusText(currentAgent.state),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color:
                                            _getStatusColor(currentAgent.state),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (currentAgent.activity != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Activity',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(currentAgent.activity!),
                      ],
                      if (currentAgent.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAgent.errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                      if (currentAgent.lastUpdate != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Last Update',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(_formatDate(currentAgent.lastUpdate!)),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Actions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isOperating ||
                                      currentAgent.state ==
                                          AgentLifecycleState.running ||
                                      currentAgent.state ==
                                          AgentLifecycleState.starting)
                                  ? null
                                  : _startAgent,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isOperating ||
                                      currentAgent.state ==
                                          AgentLifecycleState.idle ||
                                      currentAgent.state ==
                                          AgentLifecycleState.stopping)
                                  ? null
                                  : _stopAgent,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isOperating ? null : _restartAgent,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Restart'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _infoRow('ID', currentAgent.id),
                      const SizedBox(height: 8),
                      _infoRow('Name', currentAgent.name),
                      const SizedBox(height: 8),
                      _infoRow('Type', currentAgent.type),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return Colors.grey;
      case AgentLifecycleState.starting:
        return Colors.orange;
      case AgentLifecycleState.running:
        return Colors.green;
      case AgentLifecycleState.stopping:
        return Colors.orange.shade300;
      case AgentLifecycleState.error:
        return Colors.red;
      case AgentLifecycleState.offline:
        return Colors.grey.shade400;
    }
  }

  IconData _getStatusIcon(AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return Icons.pause_circle_outline;
      case AgentLifecycleState.starting:
        return Icons.play_circle_outline;
      case AgentLifecycleState.running:
        return Icons.play_circle_filled;
      case AgentLifecycleState.stopping:
        return Icons.stop_circle;
      case AgentLifecycleState.error:
        return Icons.error_outline;
      case AgentLifecycleState.offline:
        return Icons.cloud_off;
    }
  }

  String _getStatusText(AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return 'Idle';
      case AgentLifecycleState.starting:
        return 'Starting...';
      case AgentLifecycleState.running:
        return 'Running';
      case AgentLifecycleState.stopping:
        return 'Stopping...';
      case AgentLifecycleState.error:
        return 'Error';
      case AgentLifecycleState.offline:
        return 'Offline';
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return date.toLocal().toString();
    }
  }
}
