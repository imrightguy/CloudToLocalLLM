import 'package:flutter/foundation.dart';

/// Streaming message protocol for real-time communication
///
/// Represents a chunk of a streaming response from Ollama with metadata
/// for proper assembly and display in the UI.
@immutable
class StreamingMessage {
  final String id;
  final String conversationId;
  final String chunk;
  final String? reasoning; // Thinking content from the model
  final bool isComplete;
  final int sequence;
  final DateTime timestamp;
  final String? model;
  final String? error;

  const StreamingMessage({
    required this.id,
    required this.conversationId,
    required this.chunk,
    this.reasoning,
    required this.isComplete,
    required this.sequence,
    required this.timestamp,
    this.model,
    this.error,
  });

  /// Create a streaming message chunk
  factory StreamingMessage.chunk({
    required String id,
    required String conversationId,
    required String chunk,
    String? reasoning,
    required int sequence,
    String? model,
  }) {
    return StreamingMessage(
      id: id,
      conversationId: conversationId,
      chunk: chunk,
      reasoning: reasoning,
      isComplete: false,
      sequence: sequence,
      timestamp: DateTime.now(),
      model: model,
    );
  }

  /// Create a completion message (final chunk)
  factory StreamingMessage.complete({
    required String id,
    required String conversationId,
    required int sequence,
    String? model,
  }) {
    return StreamingMessage(
      id: id,
      conversationId: conversationId,
      chunk: '',
      isComplete: true,
      sequence: sequence,
      timestamp: DateTime.now(),
      model: model,
    );
  }

  /// Create an error message
  factory StreamingMessage.error({
    required String id,
    required String conversationId,
    required String error,
    required int sequence,
  }) {
    return StreamingMessage(
      id: id,
      conversationId: conversationId,
      chunk: '',
      isComplete: true,
      sequence: sequence,
      timestamp: DateTime.now(),
      error: error,
    );
  }

  /// Create from JSON (for WebSocket communication)
  factory StreamingMessage.fromJson(Map<String, dynamic> json) {
    return StreamingMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      chunk: json['chunk'] as String? ?? '',
      reasoning: json['reasoning'] as String?,
      isComplete: json['isComplete'] as bool? ?? false,
      sequence: json['sequence'] as int? ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      model: json['model'] as String?,
      error: json['error'] as String?,
    );
  }

  /// Convert to JSON (for WebSocket communication)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'chunk': chunk,
      if (reasoning != null) 'reasoning': reasoning,
      'isComplete': isComplete,
      'sequence': sequence,
      'timestamp': timestamp.toIso8601String(),
      if (model != null) 'model': model,
      if (error != null) 'error': error,
    };
  }

  /// Check if this is an error message
  bool get hasError => error != null;

  /// Check if this is a data chunk (not completion or error)
  bool get isDataChunk =>
      !isComplete && !hasError && (chunk.isNotEmpty || reasoning != null);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamingMessage &&
        other.id == id &&
        other.conversationId == conversationId &&
        other.sequence == sequence;
  }

  @override
  int get hashCode {
    return Object.hash(id, conversationId, sequence);
  }

  @override
  String toString() {
    return 'StreamingMessage(id: $id, conversationId: $conversationId, '
        'sequence: $sequence, isComplete: $isComplete, '
        'chunk: ${chunk.length} chars, reasoning: ${reasoning?.length ?? 0} chars, hasError: $hasError)';
  }

  /// Copy with modifications
  StreamingMessage copyWith({
    String? id,
    String? conversationId,
    String? chunk,
    String? reasoning,
    bool? isComplete,
    int? sequence,
    DateTime? timestamp,
    String? model,
    String? error,
  }) {
    return StreamingMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      chunk: chunk ?? this.chunk,
      reasoning: reasoning ?? this.reasoning,
      isComplete: isComplete ?? this.isComplete,
      sequence: sequence ?? this.sequence,
      timestamp: timestamp ?? this.timestamp,
      model: model ?? this.model,
      error: error ?? this.error,
    );
  }
}

/// Connection state for streaming
enum StreamingConnectionState {
  disconnected,
  connecting,
  connected,
  streaming,
  error,
  reconnecting,
}

/// Streaming connection metadata
@immutable
class StreamingConnection {
  final StreamingConnectionState state;
  final String? endpoint;
  final DateTime? lastActivity;
  final int reconnectAttempts;
  final Duration latency;
  final String? error;

  const StreamingConnection({
    required this.state,
    this.endpoint,
    this.lastActivity,
    this.reconnectAttempts = 0,
    this.latency = Duration.zero,
    this.error,
  });

  /// Create a disconnected connection
  factory StreamingConnection.disconnected({String? error}) {
    return StreamingConnection(
      state: StreamingConnectionState.disconnected,
      error: error,
    );
  }

  /// Create a connecting connection
  factory StreamingConnection.connecting(String endpoint) {
    return StreamingConnection(
      state: StreamingConnectionState.connecting,
      endpoint: endpoint,
      lastActivity: DateTime.now(),
    );
  }

  /// Create a connected connection
  factory StreamingConnection.connected(String endpoint) {
    return StreamingConnection(
      state: StreamingConnectionState.connected,
      endpoint: endpoint,
      lastActivity: DateTime.now(),
    );
  }

  /// Create a streaming connection
  factory StreamingConnection.streaming(String endpoint) {
    return StreamingConnection(
      state: StreamingConnectionState.streaming,
      endpoint: endpoint,
      lastActivity: DateTime.now(),
    );
  }

  /// Create an error connection
  factory StreamingConnection.error(String error, {String? endpoint}) {
    return StreamingConnection(
      state: StreamingConnectionState.error,
      endpoint: endpoint,
      error: error,
      lastActivity: DateTime.now(),
    );
  }

  /// Check if connection is active (connected or streaming)
  bool get isActive =>
      state == StreamingConnectionState.connected ||
      state == StreamingConnectionState.streaming;

  /// Check if connection has error
  bool get hasError => state == StreamingConnectionState.error;

  /// Copy with modifications
  StreamingConnection copyWith({
    StreamingConnectionState? state,
    String? endpoint,
    DateTime? lastActivity,
    int? reconnectAttempts,
    Duration? latency,
    String? error,
  }) {
    return StreamingConnection(
      state: state ?? this.state,
      endpoint: endpoint ?? this.endpoint,
      lastActivity: lastActivity ?? this.lastActivity,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      latency: latency ?? this.latency,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'StreamingConnection(state: $state, endpoint: $endpoint, '
        'reconnectAttempts: $reconnectAttempts, hasError: $hasError)';
  }
}
