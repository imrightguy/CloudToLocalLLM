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
}
