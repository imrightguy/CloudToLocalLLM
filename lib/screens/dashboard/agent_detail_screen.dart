import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/models/agent.dart';

class AgentDetailScreen extends StatelessWidget {
  final Agent agent;

  const AgentDetailScreen({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(agent.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusHeader(context),
          const SizedBox(height: 24),
          _buildInfoSection(context),
          const SizedBox(height: 24),
          _buildMetadataSection(context),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: agent.avatarUrl != null ? NetworkImage(agent.avatarUrl!) : null,
              child: agent.avatarUrl == null ? const Icon(Icons.smart_toy, size: 30) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agent.name, style: Theme.of(context).textTheme.headlineSmall),
                  Text('Agent ID: ${agent.agentId}', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            _StatusBadge(status: agent.status),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AGENT INFORMATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        _InfoRow(label: 'Type', value: agent.type),
        _InfoRow(label: 'Last Updated', value: agent.updatedAt.toString()),
        if (agent.clawvatarId != null) _InfoRow(label: 'Clawvatar ID', value: agent.clawvatarId!),
      ],
    );
  }

  Widget _buildMetadataSection(BuildContext context) {
    if (agent.metadata.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('METADATA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        ...agent.metadata.entries.map((e) => _InfoRow(label: e.key, value: e.value.toString())),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (status == 'active') color = Colors.green;
    if (status == 'idle') color = Colors.blue;
    if (status == 'error') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
