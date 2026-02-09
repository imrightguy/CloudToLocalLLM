import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

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

  factory AgentStatus.fromJson(Map<String, dynamic> json) {
    return AgentStatus(
      id: json['sessionId'] ?? '',
      name: json['key']?.split(':')?.last ?? 'Unknown',
      status: json['abortedLastRun'] == true ? 'error' : 'active',
      activity: 'Model: ${json['model'] ?? 'unknown'} (${json['inputTokens'] ?? 0} in, ${json['outputTokens'] ?? 0} out)',
      lastUpdate: json['updatedAt']?.toString(),
    );
  }
}

/// Service for polling agent status from OpenClaw
class AgentStatusService {
  final Logger _logger = Logger();
  final String _statusUrl;
  final Duration _pollInterval;
  Timer? _pollTimer;
  final StreamController<List<AgentStatus>> _statusController =
      StreamController<List<AgentStatus>>.broadcast();
  List<AgentStatus> _cachedStatuses = [];

  /// Create a new agent status service
  ///
  /// [statusUrl] URL to poll for agent status (default: http://localhost:3000/status.json)
  /// [pollInterval] How often to poll (default: 2 seconds)
  AgentStatusService({
    String? statusUrl,
    Duration? pollInterval,
  })  : _statusUrl = statusUrl ?? 'http://127.0.0.1:3000/status.json',
        _pollInterval = pollInterval ?? const Duration(seconds: 2);

  /// Stream of agent status updates
  Stream<List<AgentStatus>> get statusStream => _statusController.stream;

  /// Get cached agent statuses (synchronous)
  List<AgentStatus> get currentStatuses => List.unmodifiable(_cachedStatuses);

  /// Start polling for agent status
  void startPolling() {
    if (_pollTimer != null && _pollTimer!.isActive) {
      _logger.d('Agent status polling already started');
      return;
    }

    _logger.i('Starting agent status polling: $_statusUrl');
    _poll(); // Initial poll
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Stop polling for agent status
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _logger.i('Stopped agent status polling');
  }

  /// Poll status from the server
  Future<void> _poll() async {
    try {
      final response = await http
          .get(Uri.parse(_statusUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic> && data.containsKey('sessions')) {
          final sessions = data['sessions'] as List<dynamic>;
          final statuses =
              sessions.map((e) => AgentStatus.fromJson(e as Map<String, dynamic>)).toList();
          _cachedStatuses = statuses;
          _statusController.add(statuses);
          _logger.d('Polled agent status: ${statuses.length} sessions');
        }
      } else {
        _logger.w('Failed to poll agent status: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error polling agent status: $e');
      // Don't throw - continue polling even if one request fails
    }
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
    _statusController.close();
  }
}
