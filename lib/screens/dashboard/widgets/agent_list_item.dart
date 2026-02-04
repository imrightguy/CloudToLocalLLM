import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/models/agent.dart';

class AgentListItem extends StatelessWidget {
  final Agent agent;
  final VoidCallback onTap;

  const AgentListItem({
    super.key,
    required this.agent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(agent.status).withOpacity(0.1),
          backgroundImage: agent.avatarUrl != null ? NetworkImage(agent.avatarUrl!) : null,
          child: agent.avatarUrl == null ? Icon(Icons.smart_toy, color: _getStatusColor(agent.status)) : null,
        ),
        title: Text(
          agent.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Type: ${agent.type} • ID: ${agent.agentId}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(agent.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getStatusColor(agent.status).withOpacity(0.5)),
          ),
          child: Text(
            agent.status.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(agent.status),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'idle':
        return Colors.blue;
      case 'error':
        return Colors.red;
      case 'offline':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }
}
