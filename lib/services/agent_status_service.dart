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
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

  final StreamController<List<AgentStatus>> _statusController =
      StreamController<List<AgentStatus>>.broadcast();
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();
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

    _logger.i('Starting agent status polling: $_statusUrl');
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
      _logger.d('Applying backoff: polling in ${nextDelay.inSeconds}s (errors: $_consecutiveErrors)');
    }

    _pollTimer = Timer(nextDelay, () => _poll());
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
          _errorController.add(null); // Clear error
          _consecutiveErrors = 0; // Reset on success
          _logger.d('Polled agent status: ${statuses.length} sessions');
        } else {
           _consecutiveErrors++;
           _errorController.add('Invalid data from server');
           _logger.w('Invalid status data received');
        }
      } else {
        _consecutiveErrors++;
        _errorController.add('Server returned ${response.statusCode}');
        _logger.w('Failed to poll agent status: ${response.statusCode}');
      }
    } catch (e) {
      _consecutiveErrors++;
      _errorController.add('Connection error: $e');
      _logger.e('Error polling agent status: $e');
    } finally {
      if (_pollTimer != null) { // Only reschedule if we haven't stopped
        _scheduleNextPoll();
      }
    }
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
    _statusController.close();
  }
}
