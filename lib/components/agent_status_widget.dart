import 'package:flutter/material.dart';
import '../services/agent_status_service.dart';

/// Widget for displaying agent status with real-time updates
class AgentStatusWidget extends StatefulWidget {
  final AgentStatusService service;
  final bool showDetails;
  final double? width;
  final double? height;

  const AgentStatusWidget({
    super.key,
    required this.service,
    this.showDetails = true,
    this.width,
    this.height,
  });

  @override
  State<AgentStatusWidget> createState() => _AgentStatusWidgetState();
}

class _AgentStatusWidgetState extends State<AgentStatusWidget> {
  List<AgentStatus> _agents = [];

  @override
  void initState() {
    super.initState();
    _agents = widget.service.currentStatuses;
    widget.service.statusStream.listen((agents) {
      if (mounted) {
        setState(() {
          _agents = agents;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
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

  Widget _buildEmptyState() {
    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
            color: _getStatusColor().withOpacity(0.2),
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
          backgroundColor: _getStatusColorForStatus(agent.status).withOpacity(0.2),
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
                                .withOpacity(0.5),
                          ),
                    ),
                ],
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColorForStatus(agent.status).withOpacity(0.2),
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
    } else if (_agents.any((a) => a.status == 'busy' || a.status == 'thinking')) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _getStatusColorForStatus(String status) {
    switch (status) {
      case 'idle':
        return Colors.green;
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
