import 'package:flutter/foundation.dart';

/// Agent model - local stub implementation
class Agent {
  final String id;
  final String name;
  final String status;
  final String? agentId;

  Agent({
    required this.id,
    required this.name,
    required this.status,
    this.agentId,
  });

  String get agentIdValue => agentId ?? id;
}

class AgentProvider with ChangeNotifier {
  List<Agent> _agents = [];
  List<Agent> get agents => _agents;

  void setAgents(List<Agent> agents) {
    _agents = agents;
    notifyListeners();
  }

  void updateAgent(Agent agent) {
    final index =
        _agents.indexWhere((a) => a.agentIdValue == agent.agentIdValue);
    if (index >= 0) {
      _agents[index] = agent;
    } else {
      _agents.add(agent);
    }
    notifyListeners();
  }
}
