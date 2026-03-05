import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// Model context window sizes (configurable per provider)
const Map<String, int> modelContextWindows = {
  'kimi-coding/k2p5': 256000, // Kimi K2 - 256k
  'zai/glm-4.7-flash': 128000, // GLM-4.7 Flash - 128k
  'anthropic/claude-3-opus': 200000,
  'anthropic/claude-3-sonnet': 200000,
  'anthropic/claude-3-haiku': 200000,
  'google/gemini-pro-1.5': 200000,
  'google/gemini-flash-1.5': 100000,
};

/// Safety margin percentages
const int warningThreshold = 75; // Warn at 75% of context window
const int pauseThreshold = 90; // Pause at 90% of context window

/// Service for fetching and managing behavior warnings
class BehaviorWarningsService {
  final String _apiBaseUrl;
  final http.Client _client;
  Timer? _refreshTimer;

  BehaviorWarningsService({
    String? apiBaseUrl,
    http.Client? client,
  })  : _apiBaseUrl = apiBaseUrl ?? AppConfig.adminServerUrl,
        _client = client ?? http.Client();

  /// Get context usage for current session
  Future<int?> getContextUsage(String sessionKey) async {
    try {
      final response = await _client.get(
        Uri.parse(
            '$_apiBaseUrl/api/admin/context-usage?sessionKey=$sessionKey'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['context_tokens'] as int?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching context usage: $e');
      return null;
    }
  }

  /// Get pending behavior warnings
  Future<List<Warning>> getWarnings({String? sessionKey}) async {
    try {
      final queryParams = sessionKey != null ? '?sessionKey=$sessionKey' : '';
      final response = await _client.get(
        Uri.parse('$_apiBaseUrl/api/admin/behavior-warnings$queryParams'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Add dynamic context warnings if sessionKey provided
          if (sessionKey != null && data['warnings'] != null) {
            final currentWarnings = (data['warnings'] as List)
                .map((w) => Warning.fromJson(w))
                .toList();

            final contextUsage = await getContextUsage(sessionKey);
            if (contextUsage != null) {
              // Find or create context warning
              final contextWarning = Warning(
                id: 'context_dynamic_${DateTime.now().millisecondsSinceEpoch}',
                warningType: 'context_dynamic',
                message: _getContextMessage(contextUsage),
                severity: _getSeverityForContext(contextUsage),
                triggeredAt: DateTime.now(),
                acknowledged: false,
              );
              currentWarnings.add(contextWarning);
            }
            return currentWarnings;
          }
          return (data['warnings'] as List)
              .map((w) => Warning.fromJson(w))
              .toList();
        }
      }

      debugPrint('Failed to fetch warnings: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error fetching warnings: $e');
      return [];
    }
  }

  /// Generate context warning message based on current usage
  String _getContextMessage(int currentContext) {
    final model = 'zai/glm-4.7-flash';
    final contextWindow = modelContextWindows[model] ?? 128000;
    final percentage = (currentContext / contextWindow * 100).toInt();

    if (currentContext > pauseThreshold) {
      return '⚠️ Context critical: $currentContext/$contextWindow ($percentage%). MUST write to memory before continuing.';
    } else if (currentContext > warningThreshold) {
      return '⚠️ Context high: $currentContext/$contextWindow ($percentage%). Consider writing to memory to free up space.';
    } else {
      return 'Context usage: $currentContext/$contextWindow. OK.';
    }
  }

  /// Get severity based on context usage
  Severity _getSeverityForContext(int currentContext) {
    if (currentContext > pauseThreshold) {
      return Severity.error;
    } else if (currentContext > warningThreshold) {
      return Severity.warning;
    }
    return Severity.info;
  }

  /// Acknowledge a warning
  Future<bool> acknowledgeWarning(String id) async {
    try {
      final response = await _client.post(
        Uri.parse('$_apiBaseUrl/api/admin/behavior-warnings/$id/acknowledge'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error acknowledging warning: $e');
      return false;
    }
  }

  /// Clear old warnings (acknowledged ones older than 24 hours)
  Future<bool> clearOldWarnings() async {
    try {
      final response = await _client.delete(
        Uri.parse('$_apiBaseUrl/api/admin/behavior-warnings'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error clearing warnings: $e');
      return false;
    }
  }

  /// Start automatic refresh
  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      getWarnings();
    });
  }

  /// Stop automatic refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  /// Dispose resources
  void dispose() {
    stopAutoRefresh();
    _client.close();
  }
}

/// Model for a behavior warning
class Warning {
  final String id;
  final String warningType;
  final String message;
  final Severity severity;
  final DateTime triggeredAt;
  final bool acknowledged;

  Warning({
    required this.id,
    required this.warningType,
    required this.message,
    required this.severity,
    required this.triggeredAt,
    required this.acknowledged,
  });

  factory Warning.fromJson(Map<String, dynamic> json) {
    return Warning(
      id: json['id'] as String,
      warningType: json['warning_type'] as String,
      message: json['message'] as String,
      severity: _parseSeverity(json['severity'] as String),
      triggeredAt: DateTime.parse(json['triggered_at'] as String),
      acknowledged: json['acknowledged'] as bool? ?? false,
    );
  }

  static Severity _parseSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'error':
        return Severity.error;
      case 'warning':
        return Severity.warning;
      case 'info':
        return Severity.info;
      default:
        return Severity.info;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'warning_type': warningType,
      'message': message,
      'severity': severity.toString().split('.').last,
      'triggered_at': triggeredAt.toIso8601String(),
      'acknowledged': acknowledged,
    };
  }
}

/// Severity levels for warnings
enum Severity {
  info,
  warning,
  error,
}
