// Agent List Item - Stub Implementation

import 'package:flutter/material.dart';

/// Agent model - local stub
class Agent {
  final String id;
  final String name;
  final String status;

  Agent({required this.id, required this.name, required this.status});
}

/// Agent List Item widget - stub
class AgentListItem extends StatelessWidget {
  final Agent agent;
  final VoidCallback? onTap;

  const AgentListItem({super.key, required this.agent, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(Icons.person),
      ),
      title: Text(agent.name),
      subtitle: Text(agent.status),
      trailing: Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
