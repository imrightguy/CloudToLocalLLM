/// Dashboard Service - Stub Implementation
/// This service requires the CloudToLocalLLM package which is not available.
library;

class Agent {
  final String id;
  final String name;
  final String status;

  Agent({required this.id, required this.name, required this.status});

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'unknown',
    );
  }
}

class AgentEvent {
  final String eventType;
  final Map<String, dynamic> eventData;
  final DateTime timestamp;

  AgentEvent({
    required this.eventType,
    required this.eventData,
    required this.timestamp,
  });

  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    return AgentEvent(
      eventType: json['eventType'] ?? '',
      eventData: json['eventData'] ?? {},
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class DashboardService {
  DashboardService();

  Future<List<Agent>> getAgents() async {
    // Stub - returns empty list
    return [];
  }

  Future<List<AgentEvent>> getRecentEvents({int limit = 50}) async {
    // Stub - returns empty list
    return [];
  }

  void connectWebSocket({
    required Function(Map<String, dynamic>) onData,
    required Function(dynamic) onError,
  }) {
    // Stub - no-op
  }

  void disconnectWebSocket() {
    // Stub - no-op
  }
}
