import 'package:flutter/material.dart';
import '../services/agent_status_service.dart';

/// Widget for displaying agent status with real-time updates
class AgentStatusWidget extends StatefulWidget {
  final AgentStatusService? service;
  final bool showDetails;
  final double? width;
  final double? height;

  const AgentStatusWidget({
    super.key,
    this.service,
    this.showDetails = true,
    this.width,
    this.height,
  });

  @override
  State<AgentStatusWidget> createState() => _AgentStatusWidgetState();
}

class _AgentStatusWidgetState extends State<AgentStatusWidget> {
  List<AgentStatus> _agents = [];
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    if (widget.service == null) {
      _error = 'Agent status service not available';
      _isLoading = false;
      return;
    }

    _agents = widget.service!.currentStatuses;
    if (_agents.isNotEmpty) _isLoading = false;

    widget.service!.statusStream.listen((agents) {
      if (mounted) {
        setState(() {
          _agents = agents;
          _isLoading = false;
        });
      }
    });

    widget.service!.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _error = error;
          if (error != null) _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null && _agents.isEmpty) {
      return _buildErrorState();
    }

    if (_agents.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _agents.length,
              itemBuilder: (context, index) {
                return _buildAgentCard(_agents[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Connecting to OpenClaw...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Connection Problem',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                widget.service?.startPolling();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🦞',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              'No agents detected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Start an agent session to see status',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Agent Status',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_agents.length} active',
            style: TextStyle(
              color: _getStatusColor(),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentCard(AgentStatus agent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              _getStatusColorForStatus(agent.status).withValues(alpha: 0.2),
          child: Text(
            _getStatusEmoji(agent.status),
            style: TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          agent.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: widget.showDetails
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (agent.activity != null)
                    Text(
                      agent.activity!,
                      style: TextStyle(fontSize: 12),
                    ),
                  if (agent.lastUpdate != null)
                    Text(
                      'Updated: ${agent.lastUpdate}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                ],
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                _getStatusColorForStatus(agent.status).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            agent.status.toUpperCase(),
            style: TextStyle(
              color: _getStatusColorForStatus(agent.status),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    // Return overall status color based on all agents
    if (_agents.any((a) => a.status == 'error')) {
      return Colors.red;
    } else if (_agents
        .any((a) => a.status == 'busy' || a.status == 'thinking')) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _getStatusColorForStatus(String status) {
    switch (status) {
      case 'idle':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'thinking':
      case 'busy':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusEmoji(String status) {
    switch (status) {
      case 'idle':
        return '😴';
      case 'active':
        return '🚀';
      case 'thinking':
        return '🤔';
      case 'busy':
        return '⚙️';
      case 'error':
        return '❌';
      default:
        return '❓';
    }
  }
}
