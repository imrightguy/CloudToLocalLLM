class AgentEvent {
  final String id;
  final String agentId;
  final String eventType;
  final Map<String, dynamic> eventData;
  final String? correlationId;
  final DateTime timestamp;
  final String? agentName;

  AgentEvent({
    required this.id,
    required this.agentId,
    required this.eventType,
    required this.eventData,
    this.correlationId,
    required this.timestamp,
    this.agentName,
  });

  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    return AgentEvent(
      id: json['id'],
      agentId: json['agent_id'],
      eventType: json['event_type'],
      eventData: json['event_data'] ?? {},
      correlationId: json['correlation_id'],
      timestamp: DateTime.parse(json['timestamp']),
      agentName: json['agent_name'],
    );
  }
}
