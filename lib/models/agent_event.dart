import 'package:flutter/foundation.dart';

/// Structured event from a Hermes agent run.
///
/// Emitted via the /v1/runs/{run_id}/events SSE endpoint.
/// These events carry agent lifecycle information (tool calls,
/// reasoning, completion) beyond simple text deltas.
@immutable
sealed class AgentEvent {
  /// The Hermes run ID this event belongs to.
  final String runId;

  /// Server-side timestamp (seconds since epoch).
  final double timestamp;

  const AgentEvent({required this.runId, required this.timestamp});

  /// Parse a raw SSE event dict from Hermes /v1/runs/{run_id}/events.
  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    final eventType = json['event'] as String?;
    final runId = json['run_id'] as String? ?? '';
    final timestamp = (json['timestamp'] as num?)?.toDouble() ?? 0.0;

    return switch (eventType) {
      'tool.started' => AgentToolStarted.fromJson(json),
      'tool.completed' => AgentToolCompleted.fromJson(json),
      'reasoning.available' => AgentReasoningAvailable.fromJson(json),
      'message.delta' => AgentMessageDelta.fromJson(json),
      'run.completed' => AgentRunCompleted.fromJson(json),
      'run.failed' => AgentRunFailed.fromJson(json),
      _ => AgentUnknown(
          runId: runId,
          timestamp: timestamp,
          eventType: eventType ?? 'unknown',
          data: json,
        ),
    };
  }

  /// Human-readable label for the event type.
  String get eventTypeLabel;
}

// ---------------------------------------------------------------------------
// Tool events
// ---------------------------------------------------------------------------

/// A tool has started executing.
class AgentToolStarted extends AgentEvent {
  /// Tool name (e.g. "terminal", "read_file", "web_search").
  final String tool;

  /// Short human-readable preview of what the tool is doing.
  final String? preview;

  const AgentToolStarted({
    required super.runId,
    required super.timestamp,
    required this.tool,
    this.preview,
  });

  factory AgentToolStarted.fromJson(Map<String, dynamic> json) {
    return AgentToolStarted(
      runId: json['run_id'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      tool: json['tool'] as String? ?? '',
      preview: json['preview'] as String?,
    );
  }

  @override
  String get eventTypeLabel => 'tool.started';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentToolStarted &&
          other.runId == runId &&
          other.tool == tool &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(runId, tool, timestamp);
}

/// A tool has finished executing.
class AgentToolCompleted extends AgentEvent {
  /// Tool name.
  final String tool;

  /// Execution time in seconds.
  final double duration;

  /// Whether the tool reported an error.
  final bool isError;

  const AgentToolCompleted({
    required super.runId,
    required super.timestamp,
    required this.tool,
    required this.duration,
    this.isError = false,
  });

  factory AgentToolCompleted.fromJson(Map<String, dynamic> json) {
    return AgentToolCompleted(
      runId: json['run_id'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      tool: json['tool'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      isError: json['error'] as bool? ?? false,
    );
  }

  @override
  String get eventTypeLabel => 'tool.completed';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentToolCompleted &&
          other.runId == runId &&
          other.tool == tool &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(runId, tool, timestamp);
}

// ---------------------------------------------------------------------------
// Reasoning
// ---------------------------------------------------------------------------

/// Reasoning / thinking content from the model.
class AgentReasoningAvailable extends AgentEvent {
  /// The reasoning text chunk.
  final String text;

  const AgentReasoningAvailable({
    required super.runId,
    required super.timestamp,
    required this.text,
  });

  factory AgentReasoningAvailable.fromJson(Map<String, dynamic> json) {
    return AgentReasoningAvailable(
      runId: json['run_id'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String? ?? '',
    );
  }

  @override
  String get eventTypeLabel => 'reasoning.available';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentReasoningAvailable &&
          other.runId == runId &&
          other.text == text &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(runId, text, timestamp);
}

// ---------------------------------------------------------------------------
// Message delta
// ---------------------------------------------------------------------------

/// A text chunk of the agent's final response.
class AgentMessageDelta extends AgentEvent {
  /// The text delta to append.
  final String delta;

  const AgentMessageDelta({
    required super.runId,
    required super.timestamp,
    required this.delta,
  });

  factory AgentMessageDelta.fromJson(Map<String, dynamic> json) {
    return AgentMessageDelta(
      runId: json['run_id'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      delta: json['delta'] as String? ?? '',
    );
  }

  @override
  String get eventTypeLabel => 'message.delta';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentMessageDelta &&
          other.runId == runId &&
          other.delta == delta &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(runId, delta, timestamp);
}

// ---------------------------------------------------------------------------
// Run lifecycle
// ---------------------------------------------------------------------------

/// The agent run completed successfully.
class AgentRunCompleted extends AgentEvent {
  /// The final output text.
  final String output;

  /// Token usage stats.
  final Map<String, int>? usage;

  const AgentRunCompleted({
    required super.runId,
    required super.timestamp,
    required this.output,
    this.usage,
  });

  factory AgentRunCompleted.fromJson(Map<String, dynamic> json) {
    final usageRaw = json['usage'];
    Map<String, int>? usage;
    if (usageRaw is Map) {
      usage = usageRaw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
    }

    return AgentRunCompleted(
      runId: json['run_id'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      output: json['output'] as String? ?? '',
      usage: usage,
    );
  }

  @override
  String get eventTypeLabel => 'run.completed';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentRunCompleted &&
          other.runId == runId &&
          other.output == output;

  @override
  int get hashCode => Object.hash(runId, output);
}

/// The agent run failed.
class AgentRunFailed extends AgentEvent {
  /// Error description.
  final String error;

  const AgentRunFailed({
    required super.runId,
    required super.timestamp,
    required this.error,
  });

  factory AgentRunFailed.fromJson(Map<String, dynamic> json) {
    return AgentRunFailed(
      runId: json['run_id'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String? ?? 'Unknown error',
    );
  }

  @override
  String get eventTypeLabel => 'run.failed';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentRunFailed && other.runId == runId && other.error == error;

  @override
  int get hashCode => Object.hash(runId, error);
}

// ---------------------------------------------------------------------------
// Unknown / forward-compatible
// ---------------------------------------------------------------------------

/// An event type we don't recognize yet — kept for forward compatibility.
class AgentUnknown extends AgentEvent {
  final String eventType;
  final Map<String, dynamic> data;

  const AgentUnknown({
    required super.runId,
    required super.timestamp,
    required this.eventType,
    required this.data,
  });

  @override
  String get eventTypeLabel => eventType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentUnknown &&
          other.runId == runId &&
          other.eventType == eventType;

  @override
  int get hashCode => Object.hash(runId, eventType);
}

// ---------------------------------------------------------------------------
// Tool call tracking (accumulates started/completed pairs for UI display)
// ---------------------------------------------------------------------------

/// Tracks a single tool execution across its lifecycle.
@immutable
class ToolCall {
  /// Tool name.
  final String name;

  /// Human-readable preview of what the tool is doing.
  final String? preview;

  /// Whether the tool has completed.
  final bool isCompleted;

  /// Whether the tool reported an error.
  final bool isError;

  /// Execution duration in seconds (0.0 if still running).
  final double durationSeconds;

  /// When the tool started.
  final DateTime startedAt;

  const ToolCall({
    required this.name,
    this.preview,
    this.isCompleted = false,
    this.isError = false,
    this.durationSeconds = 0.0,
    required this.startedAt,
  });

  ToolCall copyWith({
    String? name,
    String? preview,
    bool? isCompleted,
    bool? isError,
    double? durationSeconds,
    DateTime? startedAt,
  }) {
    return ToolCall(
      name: name ?? this.name,
      preview: preview ?? this.preview,
      isCompleted: isCompleted ?? this.isCompleted,
      isError: isError ?? this.isError,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  /// Emoji for common tool names.
  String get emoji {
    // Match Hermes agent tool emoji conventions
    switch (name) {
      case 'terminal':
        return '💻';
      case 'read_file':
        return '📄';
      case 'write_file':
      case 'patch':
        return '✏️';
      case 'web_search':
        return '🔍';
      case 'web_extract':
        return '🌐';
      case 'browser_navigate':
        return '🧭';
      case 'browser_snapshot':
      case 'browser_vision':
        return '👁️';
      case 'browser_click':
        return '👆';
      case 'execute_code':
        return '⚡';
      case 'memory':
        return '🧠';
      case 'send_message':
        return '📨';
      default:
        return '🔧';
    }
  }
}
