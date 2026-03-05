library;

import 'dart:convert';

/// Model representing the state of a single model instance
class ModelInstanceState {
  /// Provider name (e.g., "zhipu", "google", "moonshot")
  final String provider;

  /// Model name (e.g., "glm-4", "gemini-pro")
  final String model;

  /// Current status of the instance
  final String status;

  /// Number of currently active requests
  final int activeRequests;

  /// Maximum concurrent requests allowed
  final int maxConcurrent;

  /// Rate limiting tier
  final String tier;

  /// Whether the model is currently rate limited
  final bool rateLimited;

  const ModelInstanceState({
    required this.provider,
    required this.model,
    required this.status,
    required this.activeRequests,
    required this.maxConcurrent,
    required this.tier,
    required this.rateLimited,
  });

  /// Create instance from JSON
  factory ModelInstanceState.fromJson(Map<String, dynamic> json) {
    return ModelInstanceState(
      provider: json['provider'] as String,
      model: json['model'] as String,
      status: json['status'] as String,
      activeRequests: json['activeRequests'] as int,
      maxConcurrent: json['maxConcurrent'] as int,
      tier: json['tier'] as String,
      rateLimited: json['rateLimited'] as bool,
    );
  }

  /// Create instance from JSON string
  factory ModelInstanceState.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return ModelInstanceState.fromJson(json);
  }
}

/// Model representing the overall gateway process state
class GatewayInstanceState {
  /// Current gateway status
  final String status;

  /// When the gateway was started
  final DateTime? startedAt;

  /// Error message if status is error
  final String? errorMessage;

  /// Process ID of the gateway
  final int? pid;

  /// Port the gateway is listening on
  final int? port;

  const GatewayInstanceState({
    required this.status,
    this.startedAt,
    this.errorMessage,
    this.pid,
    this.port,
  });

  /// Create instance from JSON
  factory GatewayInstanceState.fromJson(Map<String, dynamic> json) {
    return GatewayInstanceState(
      status: json['status'] as String,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
      pid: json['pid'] as int?,
      port: json['port'] as int?,
    );
  }

  /// Create instance from JSON string
  factory GatewayInstanceState.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return GatewayInstanceState.fromJson(json);
  }

  /// Get uptime duration based on startedAt
  Duration? get uptime {
    if (startedAt == null) return null;
    return DateTime.now().difference(startedAt!);
  }
}
