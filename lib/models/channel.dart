library;

/// Gateway communication channel model
///
/// Represents a channel in the OpenClaw Gateway messaging system.
/// Channels are used for organizing and tracking communication streams.
class GatewayChannel {
  /// Unique identifier for the channel
  final String id;

  /// Display name of the channel
  final String name;

  /// Optional description of the channel's purpose
  final String? description;

  /// Total number of messages in this channel
  final int messageCount;

  /// Timestamp of the last activity in this channel
  final DateTime? lastActivity;

  /// Number of unread messages
  final int unreadCount;

  const GatewayChannel({
    required this.id,
    required this.name,
    this.description,
    required this.messageCount,
    this.lastActivity,
    required this.unreadCount,
  });

  /// Creates a GatewayChannel from JSON data
  ///
  /// TODO: Replace with actual API integration
  factory GatewayChannel.fromJson(Map<String, dynamic> json) {
    return GatewayChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      messageCount: json['messageCount'] as int? ?? 0,
      lastActivity: json['lastActivity'] != null
          ? DateTime.parse(json['lastActivity'] as String)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  /// Creates a copy of this GatewayChannel with the given fields replaced
  GatewayChannel copyWith({
    String? id,
    String? name,
    String? description,
    int? messageCount,
    DateTime? lastActivity,
    int? unreadCount,
  }) {
    return GatewayChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      messageCount: messageCount ?? this.messageCount,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Convert to JSON (for testing purposes)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'messageCount': messageCount,
      'lastActivity': lastActivity?.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }

  @override
  String toString() {
    return 'GatewayChannel(id: $id, name: $name, messageCount: $messageCount, '
        'unreadCount: $unreadCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GatewayChannel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.messageCount == messageCount &&
        other.lastActivity == lastActivity &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        messageCount.hashCode ^
        lastActivity.hashCode ^
        unreadCount.hashCode;
  }
}
