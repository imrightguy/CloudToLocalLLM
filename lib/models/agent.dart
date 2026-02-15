class Agent {
  final String id;
  final String userId;
  final String name;
  final String agentId;
  final String type;
  final String status;
  final String? avatarUrl;
  final String? clawvatarId;
  final Map<String, dynamic> metadata;
  final DateTime updatedAt;

  Agent({
    required this.id,
    required this.userId,
    required this.name,
    required this.agentId,
    required this.type,
    required this.status,
    this.avatarUrl,
    this.clawvatarId,
    required this.metadata,
    required this.updatedAt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'],
      userId: json['user_id'] ?? '',
      name: json['name'],
      agentId: json['agent_id'],
      type: json['type'],
      status: json['status'],
      avatarUrl: json['avatar_url'],
      clawvatarId: json['clawvatar_id'],
      metadata: json['metadata'] ?? {},
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
