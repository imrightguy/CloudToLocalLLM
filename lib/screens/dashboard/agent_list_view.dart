import 'package:flutter/material.dart';

import 'package:cloudtolocalllm/models/agent.dart';
import 'package:cloudtolocalllm/screens/dashboard/widgets/agent_avatar_card.dart';
import 'package:cloudtolocalllm/screens/dashboard/widgets/agent_list_item.dart';

/// Grid view showing all agents with their status
class AgentListView extends StatelessWidget {
  final List<Agent> agents;
  final Function(Agent) onAgentTap;

  const AgentListView({
    super.key,
    required this.agents,
    required this.onAgentTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No agents found',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agents will appear here once they start sending events',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Status filter bar
        _StatusFilterBar(agents: agents),
        const Divider(height: 1),
        // Agent list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final agent = agents[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AgentListItem(
                  agent: agent,
                  onTap: () => onAgentTap(agent),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final List<Agent> agents;

  const _StatusFilterBar({required this.agents});

  @override
  Widget build(BuildContext context) {
    final activeCount = agents.where((a) => a.status == 'active').length;
    final idleCount = agents.where((a) => a.status == 'idle').length;
    final errorCount = agents.where((a) => a.status == 'error').length;
    final offlineCount = agents.where((a) => a.status == 'offline').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              count: agents.length,
              isSelected: true,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Active',
              count: activeCount,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Idle',
              count: idleCount,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Error',
              count: errorCount,
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Offline',
              count: offlineCount,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.count,
    this.isSelected = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        // TODO: Implement filtering
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      backgroundColor: color.withOpacity(0.1),
    );
  }
}
