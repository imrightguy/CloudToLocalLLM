/// Represents a single chat message in a conversation
class Message {
  final String id;
  final String content;
  final String? reasoning; // Thinking/Reasoning content from the model
  final MessageRole role;
  final DateTime timestamp;
  final String? model; // The LLM model used for assistant messages
  final MessageStatus status;
  final String? error; // Error message if status is error
  final Map<String, dynamic>? metadata;

  const Message({
    required this.id,
    required this.content,
    this.reasoning,
    required this.role,
    required this.timestamp,
    this.model,
    this.status = MessageStatus.sent,
    this.error,
    this.metadata,
  });

  /// Create a user message
  factory Message.user(
      {required String content, String? id, Map<String, dynamic>? metadata}) {
    return Message(
      id: id ?? _generateId(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      metadata: metadata,
    );
  }

  /// Create an assistant message
  factory Message.assistant({
    required String content,
    String? reasoning,
    required String model,
    String? id,
    MessageStatus status = MessageStatus.sent,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? _generateId(),
      content: content,
      reasoning: reasoning,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      model: model,
      status: status,
      error: error,
      metadata: metadata,
    );
  }

  /// Create a system message
  factory Message.system(
      {required String content, String? id, Map<String, dynamic>? metadata}) {
    return Message(
      id: id ?? _generateId(),
      content: content,
      role: MessageRole.system,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      metadata: metadata,
    );
  }

  /// Create a loading message (for when assistant is typing)
  factory Message.loading({required String model, String? id}) {
    return Message(
      id: id ?? _generateId(),
      content: '',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      model: model,
      status: MessageStatus.loading,
    );
  }

  /// Create a streaming message (for real-time streaming responses)
  factory Message.streaming({
    required String model,
    String? id,
    String content = '',
    String? reasoning,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? _generateId(),
      content: content,
      reasoning: reasoning,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      model: model,
      status: MessageStatus.streaming,
      metadata: metadata,
    );
  }

  /// Create Message from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      reasoning: json['reasoning'],
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      model: json['model'],
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      error: json['error'],
      metadata: json['metadata'],
    );
  }

  /// Convert Message to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'reasoning': reasoning,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      'model': model,
      'status': status.name,
      'error': error,
      'metadata': metadata,
    };
  }

  /// Copy with method for immutable updates
  Message copyWith({
    String? id,
    String? content,
    String? reasoning,
    MessageRole? role,
    DateTime? timestamp,
    String? model,
    MessageStatus? status,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      model: model ?? this.model,
      status: status ?? this.status,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if this is a user message
  bool get isUser => role == MessageRole.user;

  /// Check if this is an assistant message
  bool get isAssistant => role == MessageRole.assistant;

  /// Check if this is a system message
  bool get isSystem => role == MessageRole.system;

  /// Check if message is currently loading
  bool get isLoading => status == MessageStatus.loading;

  /// Check if message is currently streaming
  bool get isStreaming => status == MessageStatus.streaming;

  /// Check if message has an error
  bool get hasError => status == MessageStatus.error;

  /// Get formatted timestamp
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Generate a unique ID for the message
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Message(id: $id, role: $role, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }
}

/// Enum for message roles
enum MessageRole { user, assistant, system }

/// Enum for message status
enum MessageStatus { loading, streaming, sent, error }
