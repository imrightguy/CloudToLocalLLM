library;

/// Session data model for OpenClaw Gateway sessions
///
/// Represents an active session in the gateway, including WebSocket,
/// conversation, and user sessions with metrics and status tracking.
class SessionData {
  /// Unique identifier for the session
  final String id;

  /// Session type (websocket, conversation, user)
  final String type;

  /// User or agent name associated with this session
  final String userOrAgent;

  /// Session start timestamp
  final DateTime startTime;

  /// Total tokens used in this session
  final int tokenUsage;

  /// Number of messages exchanged
  final int messageCount;

  /// Current session status
  final String status;

  const SessionData({
    required this.id,
    required this.type,
    required this.userOrAgent,
    required this.startTime,
    required this.tokenUsage,
    required this.messageCount,
    required this.status,
  });

  /// Calculates the duration of this session
  Duration get duration => DateTime.now().difference(startTime);

  /// Creates a SessionData from JSON data
  ///
  /// TODO: Replace with actual API integration
  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      id: json['id'] as String,
      type: json['type'] as String,
      userOrAgent: json['userOrAgent'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      tokenUsage: json['tokenUsage'] as int? ?? 0,
      messageCount: json['messageCount'] as int? ?? 0,
      status: json['status'] as String,
    );
  }
}
