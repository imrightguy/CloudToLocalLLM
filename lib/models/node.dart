/// Node model for OpenClaw Gateway management
library;

class Node {
  final String id;
  final String name;
  final String type; // "local" or "cloud"
  final String status; // "online", "offline", "error"
  final int? latency; // latency in ms
  final String? tier; // "critical", "high", "medium", "unlimited"
  final int activeRequestCount;

  const Node({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.latency,
    this.tier,
    this.activeRequestCount = 0,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      latency: json['latency'] as int?,
      tier: json['tier'] as String?,
      activeRequestCount: json['activeRequestCount'] as int? ?? 0,
    );
  }
}
