import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// Subagent Registry Service
///
/// Manages subagent lifecycle through the database.
/// All agents (main, subagents, etc.) can access this registry.
class SubagentRegistryService {
  final String _apiBaseUrl;
  final http.Client _client;
  Timer? _refreshTimer;

  SubagentRegistryService({
    String? apiBaseUrl,
    http.Client? client,
  })  : _apiBaseUrl = apiBaseUrl ?? AppConfig.adminServerUrl,
        _client = client ?? http.Client();

  /// List all subagents (optionally filtered by status or agentId)
  Future<List<Subagent>> listSubagents(
      {String? status, String? agentId}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (agentId != null) queryParams['agentId'] = agentId;

      final uri = Uri.parse('$_apiBaseUrl/api/admin/subagents')
          .replace(queryParameters: queryParams);

      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['subagents'] as List)
              .map((s) => Subagent.fromJson(s))
              .toList();
        }
      }

      debugPrint('Failed to list subagents: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error listing subagents: $e');
      return [];
    }
  }

  /// Register a new subagent
  Future<Subagent?> registerSubagent({
    required String subagentId,
    required String agentId,
    String? label,
    String? task,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_apiBaseUrl/api/admin/subagents'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'subagentId': subagentId,
              'agentId': agentId,
              'label': label,
              'task': task,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Subagent.fromJson(data['subagent']);
        }
      }

      debugPrint('Failed to register subagent: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error registering subagent: $e');
      return null;
    }
  }

  /// Get a specific subagent by ID
  Future<Subagent?> getSubagent(String subagentId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_apiBaseUrl/api/admin/subagents/$subagentId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Subagent.fromJson(data['subagent']);
        }
      }

      debugPrint('Failed to get subagent: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error getting subagent: $e');
      return null;
    }
  }

  /// Update subagent status
  Future<bool> updateStatus(
    String subagentId, {
    required SubagentStatus status,
    dynamic result,
    String? logs,
    String? error,
  }) async {
    try {
      final response = await _client
          .patch(
            Uri.parse('$_apiBaseUrl/api/admin/subagents/$subagentId/status'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'status': status.name,
              if (result != null) 'result': result,
              if (logs != null) 'logs': logs,
              if (error != null) 'error': error,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating subagent status: $e');
      return false;
    }
  }

  /// Mark subagent as running
  Future<bool> markRunning(String subagentId) async {
    return updateStatus(subagentId, status: SubagentStatus.running);
  }

  /// Mark subagent as completed
  Future<bool> markCompleted(String subagentId,
      {dynamic result, String? logs}) async {
    return updateStatus(
      subagentId,
      status: SubagentStatus.completed,
      result: result,
      logs: logs,
    );
  }

  /// Mark subagent as failed
  Future<bool> markFailed(String subagentId,
      {String? error, String? logs}) async {
    return updateStatus(
      subagentId,
      status: SubagentStatus.failed,
      error: error,
      logs: logs,
    );
  }

  /// Remove a subagent from registry
  Future<bool> deleteSubagent(String subagentId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_apiBaseUrl/api/admin/subagents/$subagentId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting subagent: $e');
      return false;
    }
  }

  /// Start auto-refresh for monitoring
  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      // Auto-refresh logic can be implemented here
    });
  }

  /// Stop auto-refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  /// Dispose resources
  void dispose() {
    stopAutoRefresh();
    _client.close();
  }
}

/// Model representing a subagent
class Subagent {
  final int? id;
  final String subagentId;
  final String? label;
  final String agentId;
  final String? task;
  final SubagentStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final dynamic result;
  final String? logs;
  final String? errorMessage;

  Subagent({
    this.id,
    required this.subagentId,
    this.label,
    required this.agentId,
    this.task,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.result,
    this.logs,
    this.errorMessage,
  });

  factory Subagent.fromJson(Map<String, dynamic> json) {
    return Subagent(
      id: json['id'] as int?,
      subagentId: json['subagent_id'] as String,
      label: json['label'] as String?,
      agentId: json['agent_id'] as String,
      task: json['task'] as String?,
      status: _parseStatus(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      result: json['result_json'],
      logs: json['logs'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }

  static SubagentStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return SubagentStatus.pending;
      case 'running':
        return SubagentStatus.running;
      case 'completed':
        return SubagentStatus.completed;
      case 'failed':
        return SubagentStatus.failed;
      default:
        return SubagentStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subagent_id': subagentId,
      'label': label,
      'agent_id': agentId,
      'task': task,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'result_json': result,
      'logs': logs,
      'error_message': errorMessage,
    };
  }

  @override
  String toString() {
    return 'Subagent($subagentId, status: $status, task: $task)';
  }
}

/// Subagent status enum
enum SubagentStatus {
  pending,
  running,
  completed,
  failed,
}
