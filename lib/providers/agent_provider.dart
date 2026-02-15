import 'package:flutter/foundation.dart';
import 'package:zoidbot/models/agent.dart';

class AgentProvider with ChangeNotifier {
  List<Agent> _agents = [];
  List<Agent> get agents => _agents;

  void setAgents(List<Agent> agents) {
    _agents = agents;
    notifyListeners();
  }

  void updateAgent(Agent agent) {
    final index = _agents.indexWhere((a) => a.agentId == agent.agentId);
    if (index >= 0) {
      _agents[index] = agent;
    } else {
      _agents.add(agent);
    }
    notifyListeners();
  }
}
