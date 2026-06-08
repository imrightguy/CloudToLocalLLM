/// Tunnel Data Models
/// Request, response, and error models
library;

import 'dart:typed_data';

/// Request priority levels
enum RequestPriority {
  high, // Interactive user requests
  normal, // Batch operations
  low, // Background tasks
}

/// Tunnel request
class TunnelRequest {
  final String id;
  final String userId;
  final RequestPriority priority;
  final DateTime createdAt;
  final Duration timeout;
  final Map<String, String> headers;
  final Uint8List payload;
  final int retryCount;
  final String? correlationId;
  final Map<String, dynamic>? metadata;

  TunnelRequest({
    required this.id,
    required this.userId,
    this.priority = RequestPriority.normal,
    DateTime? createdAt,
    Duration? timeout,
    Map<String, String>? headers,
    required this.payload,
    this.retryCount = 0,
    this.correlationId,
    this.metadata,
  })  : createdAt = createdAt ?? DateTime.now(),
        timeout = timeout ?? const Duration(seconds: 30),
        headers = headers ?? {};

  /// Copy with modifications
  TunnelRequest copyWith({
    String? id,
    String? userId,
    RequestPriority? priority,
    DateTime? createdAt,
    Duration? timeout,
    Map<String, String>? headers,
    Uint8List? payload,
    int? retryCount,
    String? correlationId,
    Map<String, dynamic>? metadata,
  }) {
    return TunnelRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      timeout: timeout ?? this.timeout,
      headers: headers ?? this.headers,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      correlationId: correlationId ?? this.correlationId,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'timeout': timeout.inMilliseconds,
      'headers': headers,
      'payload': payload.toList(),
      'retryCount': retryCount,
      'correlationId': correlationId,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory TunnelRequest.fromJson(Map<String, dynamic> json) {
    final priorityStr = json['priority'] as String?;
    final priority = priorityStr != null
        ? RequestPriority.values.firstWhere(
            (e) => e.name == priorityStr,
            orElse: () => RequestPriority.normal,
          )
        : RequestPriority.normal;

    return TunnelRequest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      priority: priority,
      createdAt: DateTime.parse(json['createdAt'] as String),
      timeout: Duration(milliseconds: json['timeout'] as int),
      headers: Map<String, String>.from(json['headers'] as Map),
      payload: Uint8List.fromList((json['payload'] as List).cast<int>()),
      retryCount: json['retryCount'] as int? ?? 0,
      correlationId: json['correlationId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Tunnel response
class TunnelResponse {
  final String requestId;
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List payload;
  final Duration latency;
  final DateTime receivedAt;
  final String? correlationId;

  TunnelResponse({
    required this.requestId,
    required this.statusCode,
    Map<String, String>? headers,
    required this.payload,
    required this.latency,
    DateTime? receivedAt,
    this.correlationId,
  })  : headers = headers ?? {},
        receivedAt = receivedAt ?? DateTime.now();

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'statusCode': statusCode,
      'headers': headers,
      'payload': payload.toList(),
      'latency': latency.inMilliseconds,
      'receivedAt': receivedAt.toIso8601String(),
      'correlationId': correlationId,
    };
  }

  /// Create from JSON
  factory TunnelResponse.fromJson(Map<String, dynamic> json) {
    return TunnelResponse(
      requestId: json['requestId'] as String,
      statusCode: json['statusCode'] as int,
      headers: Map<String, String>.from(json['headers'] as Map),
      payload: Uint8List.fromList((json['payload'] as List).cast<int>()),
      latency: Duration(milliseconds: json['latency'] as int),
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      correlationId: json['correlationId'] as String?,
    );
  }
}

/// Tunnel error categories
enum TunnelErrorCategory {
  network,
  authentication,
  configuration,
  server,
  protocol,
  unknown,
}

/// Tunnel error codes
class TunnelErrorCodes {
  static const String connectionRefused = 'TUNNEL_001';
  static const String authenticationFailed = 'TUNNEL_002';
  static const String tokenExpired = 'TUNNEL_003';
  static const String serverUnavailable = 'TUNNEL_004';
  static const String rateLimitExceeded = 'TUNNEL_005';
  static const String queueFull = 'TUNNEL_006';
  static const String requestTimeout = 'TUNNEL_007';
  static const String sshError = 'TUNNEL_008';
  static const String websocketError = 'TUNNEL_009';
  static const String configurationError = 'TUNNEL_010';
  static const String dnsResolutionFailed = 'TUNNEL_011';
  static const String networkUnreachable = 'TUNNEL_012';
  static const String invalidCredentials = 'TUNNEL_013';
  static const String maxReconnectAttemptsExceeded = 'TUNNEL_014';
  static const String compressionError = 'TUNNEL_015';
  static const String protocolVersionMismatch = 'TUNNEL_016';
  static const String hostKeyVerificationFailed = 'TUNNEL_017';
  static const String channelLimitExceeded = 'TUNNEL_018';
  static const String unknown = 'TUNNEL_999';
}

/// Tunnel error
class TunnelError implements Exception {
  final String id;
  final TunnelErrorCategory category;
  final String code;
  final String message;
  final String userMessage;
  final String? suggestion;
  final DateTime timestamp;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;

  TunnelError({
    String? id,
    required this.category,
    required this.code,
    required this.message,
    String? userMessage,
    String? suggestion,
    DateTime? timestamp,
    this.stackTrace,
    this.context,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userMessage = userMessage ?? _generateUserMessage(category, code),
        suggestion = suggestion ?? _generateSuggestion(category, code),
        timestamp = timestamp ?? DateTime.now();

  /// Factory constructor from exception
  factory TunnelError.fromException(
    Exception exception, {
    TunnelErrorCategory? category,
    String? code,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final errorInfo = _categorizeException(exception);
    return TunnelError(
      category: category ?? errorInfo.category,
      code: code ?? errorInfo.code,
      message: exception.toString(),
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Factory constructor for network errors
  factory TunnelError.network({
    required String code,
    required String message,
    String? suggestion,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    return TunnelError(
      category: TunnelErrorCategory.network,
      code: code,
      message: message,
      suggestion: suggestion,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Factory constructor for authentication errors
  factory TunnelError.authentication({
    required String code,
    required String message,
    String? suggestion,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    return TunnelError(
      category: TunnelErrorCategory.authentication,
      code: code,
      message: message,
      suggestion: suggestion,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Factory constructor for configuration errors
  factory TunnelError.configuration({
    required String code,
    required String message,
    String? suggestion,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    return TunnelError(
      category: TunnelErrorCategory.configuration,
      code: code,
      message: message,
      suggestion: suggestion,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Check if error is retryable
  bool get isRetryable {
    return category == TunnelErrorCategory.network ||
        category == TunnelErrorCategory.server ||
        code == TunnelErrorCodes.requestTimeout ||
        code == TunnelErrorCodes.serverUnavailable;
  }

  /// Check if user action is needed
  bool get isUserActionable {
    return category == TunnelErrorCategory.authentication ||
        category == TunnelErrorCategory.configuration;
  }

  /// Get documentation URL
  String get documentationUrl {
    return 'https://docs.CloudToLocalLLM.com/errors/$code';
  }

  /// Generate user-friendly message based on category and code
  static String _generateUserMessage(
      TunnelErrorCategory category, String code) {
    switch (code) {
      case TunnelErrorCodes.connectionRefused:
        return 'Unable to connect to the tunnel server';
      case TunnelErrorCodes.authenticationFailed:
        return 'Authentication failed. Please check your credentials';
      case TunnelErrorCodes.tokenExpired:
        return 'Your session has expired. Please log in again';
      case TunnelErrorCodes.serverUnavailable:
        return 'The tunnel server is temporarily unavailable';
      case TunnelErrorCodes.rateLimitExceeded:
        return 'Too many requests. Please slow down';
      case TunnelErrorCodes.queueFull:
        return 'Request queue is full. Some requests may be dropped';
      case TunnelErrorCodes.requestTimeout:
        return 'Request timed out. Please try again';
      case TunnelErrorCodes.sshError:
        return 'SSH connection error occurred';
      case TunnelErrorCodes.websocketError:
        return 'WebSocket connection error occurred';
      case TunnelErrorCodes.configurationError:
        return 'Invalid configuration detected';
      case TunnelErrorCodes.dnsResolutionFailed:
        return 'Unable to resolve server address';
      case TunnelErrorCodes.networkUnreachable:
        return 'Network is unreachable. Check your internet connection';
      case TunnelErrorCodes.invalidCredentials:
        return 'Invalid credentials provided';
      case TunnelErrorCodes.maxReconnectAttemptsExceeded:
        return 'Failed to reconnect after multiple attempts';
      case TunnelErrorCodes.compressionError:
        return 'Data compression error occurred';
      case TunnelErrorCodes.protocolVersionMismatch:
        return 'Protocol version mismatch with server';
      case TunnelErrorCodes.hostKeyVerificationFailed:
        return 'Server host key verification failed';
      case TunnelErrorCodes.channelLimitExceeded:
        return 'Maximum number of channels exceeded';
      default:
        return 'An unexpected error occurred';
    }
  }

  /// Generate actionable suggestion based on category and code
  static String? _generateSuggestion(
      TunnelErrorCategory category, String code) {
    switch (code) {
      case TunnelErrorCodes.connectionRefused:
        return 'Check if the server is running and your firewall settings';
      case TunnelErrorCodes.authenticationFailed:
        return 'Verify your username and password are correct';
      case TunnelErrorCodes.tokenExpired:
        return 'Click here to re-authenticate';
      case TunnelErrorCodes.serverUnavailable:
        return 'The server will retry automatically. Your requests are queued';
      case TunnelErrorCodes.rateLimitExceeded:
        return 'Wait a moment before sending more requests';
      case TunnelErrorCodes.queueFull:
        return 'Wait for pending requests to complete';
      case TunnelErrorCodes.requestTimeout:
        return 'Check your network connection and try again';
      case TunnelErrorCodes.configurationError:
        return 'Reset to default settings or check configuration values';
      case TunnelErrorCodes.dnsResolutionFailed:
        return 'Check your DNS settings and internet connection';
      case TunnelErrorCodes.networkUnreachable:
        return 'Verify your network connection and try again';
      case TunnelErrorCodes.maxReconnectAttemptsExceeded:
        return 'Check your network connection and manually reconnect';
      case TunnelErrorCodes.hostKeyVerificationFailed:
        return 'Verify the server identity or update the host key';
      default:
        return 'Run diagnostics for more information';
    }
  }

  /// Categorize exception into error category and code
  static ({TunnelErrorCategory category, String code}) _categorizeException(
      Exception exception) {
    final exceptionStr = exception.toString().toLowerCase();

    // Network errors
    if (exceptionStr.contains('connection refused') ||
        exceptionStr.contains('econnrefused')) {
      return (
        category: TunnelErrorCategory.network,
        code: TunnelErrorCodes.connectionRefused
      );
    }
    if (exceptionStr.contains('timeout') ||
        exceptionStr.contains('timed out')) {
      return (
        category: TunnelErrorCategory.network,
        code: TunnelErrorCodes.requestTimeout
      );
    }
    if (exceptionStr.contains('dns') ||
        exceptionStr.contains('host not found')) {
      return (
        category: TunnelErrorCategory.network,
        code: TunnelErrorCodes.dnsResolutionFailed
      );
    }
    if (exceptionStr.contains('network unreachable') ||
        exceptionStr.contains('no route to host')) {
      return (
        category: TunnelErrorCategory.network,
        code: TunnelErrorCodes.networkUnreachable
      );
    }

    // Authentication errors
    if (exceptionStr.contains('authentication') ||
        exceptionStr.contains('unauthorized') ||
        exceptionStr.contains('401')) {
      return (
        category: TunnelErrorCategory.authentication,
        code: TunnelErrorCodes.authenticationFailed
      );
    }
    if (exceptionStr.contains('token expired') ||
        exceptionStr.contains('expired')) {
      return (
        category: TunnelErrorCategory.authentication,
        code: TunnelErrorCodes.tokenExpired
      );
    }

    // Server errors
    if (exceptionStr.contains('503') || exceptionStr.contains('unavailable')) {
      return (
        category: TunnelErrorCategory.server,
        code: TunnelErrorCodes.serverUnavailable
      );
    }
    if (exceptionStr.contains('429') || exceptionStr.contains('rate limit')) {
      return (
        category: TunnelErrorCategory.server,
        code: TunnelErrorCodes.rateLimitExceeded
      );
    }

    // Protocol errors
    if (exceptionStr.contains('ssh')) {
      return (
        category: TunnelErrorCategory.protocol,
        code: TunnelErrorCodes.sshError
      );
    }
    if (exceptionStr.contains('websocket') || exceptionStr.contains('ws')) {
      return (
        category: TunnelErrorCategory.protocol,
        code: TunnelErrorCodes.websocketError
      );
    }

    // Default to unknown
    return (
      category: TunnelErrorCategory.unknown,
      code: TunnelErrorCodes.unknown
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'code': code,
      'message': message,
      'userMessage': userMessage,
      'suggestion': suggestion,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
    };
  }

  /// Create from JSON
  factory TunnelError.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String;
    final category = TunnelErrorCategory.values.firstWhere(
      (e) => e.name == categoryStr,
      orElse: () => TunnelErrorCategory.unknown,
    );

    return TunnelError(
      id: json['id'] as String,
      category: category,
      code: json['code'] as String,
      message: json['message'] as String,
      userMessage: json['userMessage'] as String,
      suggestion: json['suggestion'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      context: json['context'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'TunnelError($code): $message';
  }
}

/// Connection event types
enum ConnectionEventType {
  connected,
  disconnected,
  reconnecting,
  reconnected,
  error,
  healthCheck,
  configChanged,
}

/// Connection event
class ConnectionEvent {
  final DateTime timestamp;
  final ConnectionEventType type;
  final String? message;
  final Map<String, dynamic>? metadata;

  ConnectionEvent({
    DateTime? timestamp,
    required this.type,
    this.message,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Tunnel connection state enum
enum TunnelConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Tunnel connection
class TunnelConnection {
  final String id;
  final String userId;
  final String serverUrl;
  final DateTime connectedAt;
  DateTime lastActivityAt;
  TunnelConnectionState state;
  int reconnectAttempts;
  List<ConnectionEvent> eventHistory;

  TunnelConnection({
    required this.id,
    required this.userId,
    required this.serverUrl,
    DateTime? connectedAt,
    DateTime? lastActivityAt,
    this.state = TunnelConnectionState.disconnected,
    this.reconnectAttempts = 0,
    List<ConnectionEvent>? eventHistory,
  })  : connectedAt = connectedAt ?? DateTime.now(),
        lastActivityAt = lastActivityAt ?? DateTime.now(),
        eventHistory = eventHistory ?? [];

  /// Add event to history
  void addEvent(ConnectionEvent event) {
    eventHistory.add(event);
    // Keep only last 100 events
    if (eventHistory.length > 100) {
      eventHistory.removeAt(0);
    }
  }

  /// Update state and add event
  void updateState(TunnelConnectionState newState, {String? message}) {
    state = newState;
    lastActivityAt = DateTime.now();
    addEvent(ConnectionEvent(
      type: _stateToEventType(newState),
      message: message,
    ));
  }

  /// Convert state to event type
  ConnectionEventType _stateToEventType(TunnelConnectionState state) {
    switch (state) {
      case TunnelConnectionState.connected:
        return ConnectionEventType.connected;
      case TunnelConnectionState.disconnected:
        return ConnectionEventType.disconnected;
      case TunnelConnectionState.reconnecting:
        return ConnectionEventType.reconnecting;
      case TunnelConnectionState.error:
        return ConnectionEventType.error;
      default:
        return ConnectionEventType.connected;
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'serverUrl': serverUrl,
      'connectedAt': connectedAt.toIso8601String(),
      'lastActivityAt': lastActivityAt.toIso8601String(),
      'state': state.name,
      'reconnectAttempts': reconnectAttempts,
      'eventHistory': eventHistory
          .map((e) => {
                'timestamp': e.timestamp.toIso8601String(),
                'type': e.type.name,
                'message': e.message,
                'metadata': e.metadata,
              })
          .toList(),
    };
  }

  /// Create from JSON
  factory TunnelConnection.fromJson(Map<String, dynamic> json) {
    final stateStr = json['state'] as String;
    final state = TunnelConnectionState.values.firstWhere(
      (e) => e.name == stateStr,
      orElse: () => TunnelConnectionState.disconnected,
    );

    final eventHistoryJson = json['eventHistory'] as List<dynamic>?;
    final eventHistory = <ConnectionEvent>[];
    if (eventHistoryJson != null) {
      for (final e in eventHistoryJson) {
        try {
          eventHistory.add(ConnectionEvent(
            timestamp: DateTime.parse(e['timestamp'] as String),
            type: ConnectionEventType.values.firstWhere(
              (t) => t.name == e['type'],
              orElse: () => ConnectionEventType.connected,
            ),
            message: e['message'] as String?,
            metadata: e['metadata'] as Map<String, dynamic>?,
          ));
        } catch (_) {
          // Skip malformed event history entries
        }
      }
    }

    return TunnelConnection(
      id: json['id'] as String,
      userId: json['userId'] as String,
      serverUrl: json['serverUrl'] as String,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      lastActivityAt: DateTime.parse(json['lastActivityAt'] as String),
      state: state,
      reconnectAttempts: json['reconnectAttempts'] as int,
      eventHistory: eventHistory,
    );
  }
}

// ConnectionQuality and TunnelHealthMetrics are imported from tunnel_health_metrics.dart

/// Tunnel metrics for detailed analysis
class TunnelMetrics {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final double successRate;
  final Duration averageLatency;
  final Duration p95Latency;
  final Duration p99Latency;
  final int reconnectionCount;
  final Duration totalUptime;
  final Map<String, int> errorCounts;

  TunnelMetrics({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.successRate,
    required this.averageLatency,
    required this.p95Latency,
    required this.p99Latency,
    required this.reconnectionCount,
    required this.totalUptime,
    required this.errorCounts,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'successRate': successRate,
      'averageLatency': averageLatency.inMilliseconds,
      'p95Latency': p95Latency.inMilliseconds,
      'p99Latency': p99Latency.inMilliseconds,
      'reconnectionCount': reconnectionCount,
      'totalUptime': totalUptime.inMilliseconds,
      'errorCounts': errorCounts,
    };
  }

  /// Create from JSON
  factory TunnelMetrics.fromJson(Map<String, dynamic> json) {
    return TunnelMetrics(
      totalRequests: json['totalRequests'] as int,
      successfulRequests: json['successfulRequests'] as int,
      failedRequests: json['failedRequests'] as int,
      successRate: (json['successRate'] as num).toDouble(),
      averageLatency: Duration(milliseconds: json['averageLatency'] as int),
      p95Latency: Duration(milliseconds: json['p95Latency'] as int),
      p99Latency: Duration(milliseconds: json['p99Latency'] as int),
      reconnectionCount: json['reconnectionCount'] as int,
      totalUptime: Duration(milliseconds: json['totalUptime'] as int),
      errorCounts: Map<String, int>.from(json['errorCounts'] as Map),
    );
  }

  /// Create empty metrics
  factory TunnelMetrics.empty() {
    return TunnelMetrics(
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      successRate: 0.0,
      averageLatency: Duration.zero,
      p95Latency: Duration.zero,
      p99Latency: Duration.zero,
      reconnectionCount: 0,
      totalUptime: Duration.zero,
      errorCounts: {},
    );
  }

  /// Export in Prometheus format
  Map<String, dynamic> toPrometheusFormat() {
    return {
      'tunnel_requests_total': totalRequests,
      'tunnel_requests_success_total': successfulRequests,
      'tunnel_requests_failed_total': failedRequests,
      'tunnel_request_success_rate': successRate,
      'tunnel_request_latency_avg_ms': averageLatency.inMilliseconds,
      'tunnel_request_latency_p95_ms': p95Latency.inMilliseconds,
      'tunnel_request_latency_p99_ms': p99Latency.inMilliseconds,
      'tunnel_reconnection_count': reconnectionCount,
      'tunnel_uptime_seconds': totalUptime.inSeconds,
    };
  }
}

/// Server-side metrics interface (for reference)
/// This will be implemented in TypeScript on the server
class ServerMetrics {
  final int activeConnections;
  final int totalConnections;
  final double connectionRate;
  final int requestCount;
  final int successCount;
  final int errorCount;
  final double successRate;
  final double averageLatency;
  final double p50Latency;
  final double p95Latency;
  final double p99Latency;
  final int bytesReceived;
  final int bytesSent;
  final double requestsPerSecond;
  final Map<String, int> errorsByCategory;
  final double errorRate;
  final int activeUsers;
  final Map<String, int> requestsByUser;
  final double memoryUsage;
  final double cpuUsage;
  final Duration uptime;
  final DateTime timestamp;
  final Duration window;

  ServerMetrics({
    required this.activeConnections,
    required this.totalConnections,
    required this.connectionRate,
    required this.requestCount,
    required this.successCount,
    required this.errorCount,
    required this.successRate,
    required this.averageLatency,
    required this.p50Latency,
    required this.p95Latency,
    required this.p99Latency,
    required this.bytesReceived,
    required this.bytesSent,
    required this.requestsPerSecond,
    required this.errorsByCategory,
    required this.errorRate,
    required this.activeUsers,
    required this.requestsByUser,
    required this.memoryUsage,
    required this.cpuUsage,
    required this.uptime,
    required this.timestamp,
    required this.window,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'activeConnections': activeConnections,
      'totalConnections': totalConnections,
      'connectionRate': connectionRate,
      'requestCount': requestCount,
      'successCount': successCount,
      'errorCount': errorCount,
      'successRate': successRate,
      'averageLatency': averageLatency,
      'p50Latency': p50Latency,
      'p95Latency': p95Latency,
      'p99Latency': p99Latency,
      'bytesReceived': bytesReceived,
      'bytesSent': bytesSent,
      'requestsPerSecond': requestsPerSecond,
      'errorsByCategory': errorsByCategory,
      'errorRate': errorRate,
      'activeUsers': activeUsers,
      'requestsByUser': requestsByUser,
      'memoryUsage': memoryUsage,
      'cpuUsage': cpuUsage,
      'uptime': uptime.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'window': window.inMilliseconds,
    };
  }

  /// Create from JSON
  factory ServerMetrics.fromJson(Map<String, dynamic> json) {
    return ServerMetrics(
      activeConnections: json['activeConnections'] as int,
      totalConnections: json['totalConnections'] as int,
      connectionRate: (json['connectionRate'] as num).toDouble(),
      requestCount: json['requestCount'] as int,
      successCount: json['successCount'] as int,
      errorCount: json['errorCount'] as int,
      successRate: (json['successRate'] as num).toDouble(),
      averageLatency: (json['averageLatency'] as num).toDouble(),
      p50Latency: (json['p50Latency'] as num).toDouble(),
      p95Latency: (json['p95Latency'] as num).toDouble(),
      p99Latency: (json['p99Latency'] as num).toDouble(),
      bytesReceived: json['bytesReceived'] as int,
      bytesSent: json['bytesSent'] as int,
      requestsPerSecond: (json['requestsPerSecond'] as num).toDouble(),
      errorsByCategory: Map<String, int>.from(json['errorsByCategory'] as Map),
      errorRate: (json['errorRate'] as num).toDouble(),
      activeUsers: json['activeUsers'] as int,
      requestsByUser: Map<String, int>.from(json['requestsByUser'] as Map),
      memoryUsage: (json['memoryUsage'] as num).toDouble(),
      cpuUsage: (json['cpuUsage'] as num).toDouble(),
      uptime: Duration(milliseconds: json['uptime'] as int),
      timestamp: DateTime.parse(json['timestamp'] as String),
      window: Duration(milliseconds: json['window'] as int),
    );
  }
}

/// User-specific metrics (for reference)
class UserMetrics {
  final String userId;
  final int connectionCount;
  final int requestCount;
  final double successRate;
  final double averageLatency;
  final int dataTransferred;
  final int rateLimitViolations;
  final DateTime lastActivity;

  UserMetrics({
    required this.userId,
    required this.connectionCount,
    required this.requestCount,
    required this.successRate,
    required this.averageLatency,
    required this.dataTransferred,
    required this.rateLimitViolations,
    required this.lastActivity,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'connectionCount': connectionCount,
      'requestCount': requestCount,
      'successRate': successRate,
      'averageLatency': averageLatency,
      'dataTransferred': dataTransferred,
      'rateLimitViolations': rateLimitViolations,
      'lastActivity': lastActivity.toIso8601String(),
    };
  }

  /// Create from JSON
  factory UserMetrics.fromJson(Map<String, dynamic> json) {
    return UserMetrics(
      userId: json['userId'] as String,
      connectionCount: json['connectionCount'] as int,
      requestCount: json['requestCount'] as int,
      successRate: (json['successRate'] as num).toDouble(),
      averageLatency: (json['averageLatency'] as num).toDouble(),
      dataTransferred: json['dataTransferred'] as int,
      rateLimitViolations: json['rateLimitViolations'] as int,
      lastActivity: DateTime.parse(json['lastActivity'] as String),
    );
  }
}
