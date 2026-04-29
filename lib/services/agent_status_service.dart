import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../database/local_brain.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'connection_manager_service.dart';

/// Agent status data model
class AgentStatus {
  final String id;
  final String name;
  final String status;
  final String? activity;
  final String? lastUpdate;

  AgentStatus({
    required this.id,
    required this.name,
    required this.status,
    this.activity,
    this.lastUpdate,
  });

  factory AgentStatus.fromSessionInfo(dynamic session) {
    final sessionId = session.sessionId as String?;
    final key = session.key as String?;
    return AgentStatus(
      id: sessionId ?? '',
      name: key?.split(':').last ?? 'Unknown',
      status: session.abortedLastRun == true ? 'error' : 'active',
      activity:
          'Model: ${session.model ?? 'unknown'} (${session.inputTokens ?? 0} in, ${session.outputTokens ?? 0} out)',
      lastUpdate: session.updatedAt?.toIso8601String(),
    );
  }

  factory AgentStatus.fromJson(Map<String, dynamic> json) {
    return AgentStatus(
      id: json['sessionId'] ?? '',
      name: json['key']?.split(':')?.last ?? 'Unknown',
      status: json['abortedLastRun'] == true ? 'error' : 'active',
      activity:
          'Model: ${json['model'] ?? 'unknown'} (${json['inputTokens'] ?? 0} in, ${json['outputTokens'] ?? 0} out)',
      lastUpdate: json['updatedAt']?.toString(),
    );
  }
}

/// Service for polling agent status from OpenClaw via WebSocket
class AgentStatusService {
  final Logger _logger = Logger();
  final Duration _pollInterval;
  final LocalBrain? _db;
  final ConnectionManagerService? _connectionManager;
  Timer? _pollTimer;
  int _consecutiveErrors = 0;
  static const _uuid = Uuid();

  final StreamController<List<AgentStatus>> _statusController =
      StreamController<List<AgentStatus>>.broadcast();
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();
  List<AgentStatus> _cachedStatuses = [];

  /// Create a new agent status service
  ///
  /// [connectionManager] Connection manager for WebSocket communication
  /// [pollInterval] How often to poll (default: 2 seconds)
  AgentStatusService({
    ConnectionManagerService? connectionManager,
    Duration? pollInterval,
    LocalBrain? db,
  })  : _connectionManager = connectionManager,
        _pollInterval = pollInterval ?? const Duration(seconds: 2),
        _db = db {
    debugPrint('[AgentStatusService] Initialized with WebSocket polling');
  }

  /// Stream of agent status updates
  Stream<List<AgentStatus>> get statusStream => _statusController.stream;

  /// Stream of connection errors
  Stream<String?> get errorStream => _errorController.stream;

  /// Get cached agent statuses (synchronous)
  List<AgentStatus> get currentStatuses => List.unmodifiable(_cachedStatuses);

  /// Start polling for agent status
  void startPolling() {
    if (_pollTimer != null && _pollTimer!.isActive) {
      _logger.d('Agent status polling already started');
      return;
    }

    _logger.i('Starting agent status polling via WebSocket');
    _scheduleNextPoll();
  }

  /// Schedule next poll with backoff if needed
  void _scheduleNextPoll() {
    _pollTimer?.cancel();

    Duration nextDelay = _pollInterval;
    if (_consecutiveErrors > 0) {
      // Exponential backoff: base interval * 2^errors (max 32x interval)
      int exponent = _consecutiveErrors > 5 ? 5 : _consecutiveErrors;
      nextDelay = _pollInterval * (1 << exponent);
      _logger.d(
          'Applying backoff: polling in ${nextDelay.inSeconds}s (errors: $_consecutiveErrors)');
    }

    _pollTimer = Timer(nextDelay, _poll);
  }

  /// Stop polling for agent status
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _logger.i('Stopped agent status polling');
  }

  /// Poll status from the server via WebSocket
  Future<void> _poll() async {
    try {
      if (_connectionManager == null) {
        _consecutiveErrors++;
        _errorController.add('Connection manager not available');
        _logger.w('Connection manager not available');
        return;
      }

      if (!_connectionManager.isConnected) {
        _consecutiveErrors++;
        _errorController.add('WebSocket not connected');
        _logger.w('WebSocket not connected');
        return;
      }

      // Get sessions list via WebSocket
      final sessions = await _connectionManager.getSessionsList();

      final statuses = sessions
          .whereType<Map<String, dynamic>>()
          .map(AgentStatus.fromJson)
          .toList();

      _cachedStatuses = statuses;
      _statusController.add(statuses);
      _errorController.add(null); // Clear error
      _consecutiveErrors = 0; // Reset on success
      _logger.d('Polled agent status: ${statuses.length} sessions');

      // Save to Local Brain
      if (_db != null) {
        for (final agent in statuses) {
          await _db.upsertAgent(AgentsCompanion(
            id: Value(agent.id),
            name: Value(agent.name),
            agentId: Value(agent.id),
            type: const Value('custom'),
            status: Value(agent.status),
            activity: Value(agent.activity),
            lastUpdate: Value(agent.lastUpdate != null
                ? DateTime.tryParse(agent.lastUpdate!)
                : null),
            updatedAt: Value(DateTime.now()),
          ));

          await _db.addAgentEvent(AgentEventsCompanion(
            id: Value(_uuid.v4()),
            agentId: Value(agent.id),
            eventType: const Value('status_update'),
            eventData: Value(_encodeEventData({
              'status': agent.status,
              'activity': agent.activity,
              'lastUpdate': agent.lastUpdate,
            })),
            timestamp: Value(DateTime.now()),
            synced: const Value(true),
          ));
        }
        _logger.d('Saved ${statuses.length} agents to LocalBrain');
      }
    } catch (e, stack) {
      _consecutiveErrors++;
      final error = 'WebSocket error: $e';
      _errorController.add(error);
      _logger.e('Error polling agent status: $e');
      debugPrint('[AgentStatusService] ✗ $error');
      debugPrint('[AgentStatusService] Stack: $stack');
    } finally {
      if (_pollTimer != null) {
        // Only reschedule if we haven't stopped
        _scheduleNextPoll();
      }
    }
  }

  String _encodeEventData(Map<String, dynamic> data) {
    // Simple JSON encode without dart:convert to avoid import issues
    final parts = <String>[];
    data.forEach((key, value) {
      final encodedValue = value != null ? '"$value"' : 'null';
      parts.add('"$key":$encodedValue');
    });
    return '{${parts.join(',')}}';
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
    _statusController.close();
  }
}
