/// Agent Detail Screen - Shows detailed information about a specific agent
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/agent_lifecycle_service.dart';

/// Agent Detail Screen
class AgentDetailScreen extends StatefulWidget {
  final String agentId;

  const AgentDetailScreen({
    super.key,
    required this.agentId,
  });

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAgentDetails();
  }

  Future<void> _loadAgentDetails() async {
    setState(() => _isLoading = true);
    final service = context.read<AgentLifecycleService>();
    try {
      await service.getAgentStatus(widget.agentId);
    } catch (e) {
      debugPrint('[AgentDetailScreen] Failed to load agent: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startAgent() async {
    final service = context.read<AgentLifecycleService>();
    final result = await service.startAgent(widget.agentId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Unknown error'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    await _loadAgentDetails();
  }

  Future<void> _stopAgent() async {
    final service = context.read<AgentLifecycleService>();
    final result = await service.stopAgent(widget.agentId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Unknown error'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    await _loadAgentDetails();
  }

  Future<void> _restartAgent() async {
    final service = context.read<AgentLifecycleService>();
    final result = await service.restartAgent(widget.agentId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Unknown error'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    await _loadAgentDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentLifecycleService>(
      builder: (context, service, child) {
        final agent = service.getAgent(widget.agentId);

        if (agent == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Agent Details'),
              leading: BackButton(
                onPressed: () {
                  if (GoRouter.of(context).canPop()) {
                    context.pop();
                  } else {
                    context.go('/agents');
                  }
                },
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Agent not found'),
                  const SizedBox(height: 8),
                  Text('ID: ${widget.agentId}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadAgentDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(agent.name),
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
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _loadAgentDetails,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status Card
              _buildStatusCard(agent),

              const SizedBox(height: 16),

              // Actions Card
              _buildActionsCard(agent),

              const SizedBox(height: 16),

              // Information Card
              _buildInformationCard(agent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(AgentInfo agent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(agent.state),
                  color: _getStatusColor(agent.state),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        _getStatusText(agent.state),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: _getStatusColor(agent.state),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (agent.activity != null) ...[
              const SizedBox(height: 16),
              Text(
                'Activity',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(agent.activity!),
            ],
            if (agent.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                'Error',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                agent.errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
            if (agent.lastUpdate != null) ...[
              const SizedBox(height: 16),
              Text(
                'Last Update',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(_formatDate(agent.lastUpdate!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(AgentInfo agent) {
    final canStart = agent.state == AgentLifecycleState.idle ||
        agent.state == AgentLifecycleState.error ||
        agent.state == AgentLifecycleState.offline;
    final canStop = agent.state == AgentLifecycleState.running ||
        agent.state == AgentLifecycleState.starting;

    return Card(
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
                    onPressed: canStart ? _startAgent : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canStop ? _stopAgent : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _restartAgent,
              icon: const Icon(Icons.refresh),
              label: const Text('Restart'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard(AgentInfo agent) {
    return Card(
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
            _infoRow('ID', agent.id),
            const SizedBox(height: 8),
            _infoRow('Name', agent.name),
            const SizedBox(height: 8),
            _infoRow('Type', agent.type),
          ],
        ),
      ),
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
