import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Agent state enumeration
enum AgentState {
  idle,
  thinking,
  busy,
  error,
}

/// Agent status data model
class AgentStatus {
  final AgentState state;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AgentStatus({
    required this.state,
    required this.message,
    required this.timestamp,
    this.metadata,
  });

  factory AgentStatus.fromJson(Map<String, dynamic> json) {
    return AgentStatus(
      state: _parseAgentState(json['state'] as String?),
      message: json['message'] as String? ?? 'No message',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static AgentState _parseAgentState(String? value) {
    switch (value?.toLowerCase()) {
      case 'idle':
        return AgentState.idle;
      case 'thinking':
        return AgentState.thinking;
      case 'busy':
        return AgentState.busy;
      case 'error':
        return AgentState.error;
      default:
        return AgentState.idle;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'AgentStatus(state: $state, message: $message, timestamp: $timestamp)';
  }
}

/// Service for fetching and managing agent status with retry/backoff logic
class AgentStatusService {
  // Configuration
  static const int _maxConsecutiveErrors = 5;
  static const Duration _initialBackoff = Duration(seconds: 1);
  static const double _backoffMultiplier = 2.0;
  static const Duration _maxBackoff = Duration(minutes: 5);

  // Stream controllers
  final _statusController = StreamController<AgentStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // State
  final AppConfig _config = AppConfig();
  Timer? _pollTimer;
  Timer? _backoffTimer;

  // Backoff state
  int _consecutiveErrors = 0;
  DateTime? _backoffUntil;
  bool _isBackedOff = false;
  int _currentBackoffIndex = 0;

  // Latest data
  AgentStatus? _latestStatus;
  String? _lastError;

  // Getters
  Stream<AgentStatus> get statusStream => _statusController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isBackedOff => _isBackedOff;
  DateTime? get backoffUntil => _backoffUntil;
  int get consecutiveErrors => _consecutiveErrors;
  AgentStatus? get latestStatus => _latestStatus;
  String? get lastError => _lastError;

  /// Calculate backoff duration with exponential increase
  Duration _calculateBackoff(int errorCount) {
    final backoffMs = (_initialBackoff.inMilliseconds *
            pow(_backoffMultiplier, errorCount - 1))
        .toInt();
    final cappedMs = backoffMs.clamp(
      _initialBackoff.inMilliseconds,
      _maxBackoff.inMilliseconds,
    );
    return Duration(milliseconds: cappedMs);
  }

  /// Check if we're currently in backoff period
  bool _checkBackoffStatus() {
    if (_backoffUntil == null) {
      return false;
    }

    final now = DateTime.now();
    if (now.isBefore(_backoffUntil!)) {
      _isBackedOff = true;
      return true;
    }

    // Backoff period has expired
    _isBackedOff = false;
    _backoffUntil = null;
    return false;
  }

  /// Enter backoff mode after too many consecutive errors
  void _enterBackoff() {
    if (_consecutiveErrors < _maxConsecutiveErrors) {
      return;
    }

    _currentBackoffIndex++;
    final backoffDuration = _calculateBackoff(_currentBackoffIndex);
    _backoffUntil = DateTime.now().add(backoffDuration);
    _isBackedOff = true;

    debugPrint('[AgentStatusService] Entering backoff for $backoffDuration '
        'after $_consecutiveErrors consecutive errors');

    // Schedule backoff expiration
    _backoffTimer?.cancel();
    _backoffTimer = Timer(backoffDuration, _exitBackoff);

    _errorController.add(
      'Too many connection errors. Retrying in ${backoffDuration.inSeconds}s...',
    );
  }

  /// Exit backoff mode and allow retries
  void _exitBackoff() {
    debugPrint('[AgentStatusService] Exiting backoff mode');
    _isBackedOff = false;
    _backoffUntil = null;
    _backoffTimer?.cancel();
  }

  /// Reset the error count (for manual retries)
  void resetErrorCount() {
    debugPrint('[AgentStatusService] Resetting error count');
    _consecutiveErrors = 0;
    _currentBackoffIndex = 0;
    _exitBackoff();
  }

  /// Increment error count and potentially enter backoff
  void _incrementErrorCount(String error) {
    _consecutiveErrors++;
    _lastError = error;

    debugPrint('[AgentStatusService] Connection error ($_consecutiveErrors/$_maxConsecutiveErrors): $error');

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _enterBackoff();
    } else {
      _errorController.add(error);
    }
  }

  /// Reset success state after a successful fetch
  void _onSuccess() {
    _consecutiveErrors = 0;
    _currentBackoffIndex = 0;
    _lastError = null;
    _isBackedOff = false;
    _backoffUntil = null;
  }

  /// Fetch agent status from the configured URL
  Future<AgentStatus?> fetchStatus() async {
    // Check if we're in backoff mode
    if (_checkBackoffStatus()) {
      debugPrint('[AgentStatusService] Skipping fetch: currently in backoff');
      return null;
    }

    await _config.initialize();
    final url = _config.getAgentStatusUrl();
    final timeoutMs = _config.getAgentStatusTimeoutMs();

    try {
      debugPrint('[AgentStatusService] Fetching status from: $url');

      final uri = Uri.parse(url);
      final request = await HttpClient().openUrl('GET', uri);
      request.headers.contentType = ContentType.json;

      final response = await request.close().timeout(
        Duration(milliseconds: timeoutMs),
        onTimeout: () {
          throw TimeoutException('Connection timed out after ${timeoutMs}ms');
        },
      );

      if (response.statusCode == HttpStatus.ok) {
        final responseBody = await response.transform(utf8.decoder).join();
        final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;

        final status = AgentStatus.fromJson(jsonData);
        _latestStatus = status;
        _onSuccess();

        _statusController.add(status);
        debugPrint('[AgentStatusService] Successfully fetched status: $status');

        return status;
      } else {
        throw HttpException(
          'Server returned status code ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      final error = 'Network error: ${e.message}';
      _incrementErrorCount(error);
      return null;
    } on HttpException catch (e) {
      final error = 'HTTP error: ${e.message}';
      _incrementErrorCount(error);
      return null;
    } on TimeoutException catch (e) {
      final error = 'Connection timeout: ${e.message ?? "Request timed out"}';
      _incrementErrorCount(error);
      return null;
    } on FormatException catch (e) {
      final error = 'Invalid response format: ${e.message}';
      _incrementErrorCount(error);
      return null;
    } catch (e) {
      final error = 'Unexpected error: $e';
      _incrementErrorCount(error);
      return null;
    }
  }

  /// Start periodic polling
  void startPolling() {
    stopPolling();

    // Poll immediately on start
    fetchStatus();

    // Set up periodic polling
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      final intervalMs = prefs.getInt('agent_status_poll_interval_ms') ??
          AppConfig.defaultAgentStatusPollIntervalMs;

      _pollTimer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => fetchStatus(),
      );
    });
  }

  /// Stop periodic polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Restart polling (useful after config changes)
  void restartPolling() {
    stopPolling();
    startPolling();
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
    _backoffTimer?.cancel();
    _statusController.close();
    _errorController.close();
  }

  /// Power function for backoff calculation
  static double pow(double base, int exponent) {
    if (exponent == 0) return 1.0;
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
