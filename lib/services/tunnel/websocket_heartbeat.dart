/// WebSocket Heartbeat Manager
/// Implements ping/pong protocol for connection health monitoring
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Heartbeat status
enum HeartbeatStatus {
  stopped,
  running,
  waitingForPong,
  timeout,
}

/// WebSocket heartbeat manager
///
/// Implements ping/pong protocol to detect connection loss:
/// 1. Sends ping every [pingInterval]
/// 2. Expects pong within [pongTimeout]
/// 3. Triggers [onConnectionLost] if pong not received
class WebSocketHeartbeat {
  final WebSocketChannel channel;
  final Duration pingInterval;
  final Duration pongTimeout;
  final void Function()? onConnectionLost;
  final void Function(String message)? onLog;

  Timer? _pingTimer;
  Timer? _pongTimer;
  DateTime? _lastPongReceived;
  DateTime? _lastPingSent;
  HeartbeatStatus _status = HeartbeatStatus.stopped;
  int _pingsSent = 0;
  int _pongsReceived = 0;
  int _missedPongs = 0;

  WebSocketHeartbeat({
    required this.channel,
    Duration? pingInterval,
    Duration? pongTimeout,
    this.onConnectionLost,
    this.onLog,
  })  : pingInterval = pingInterval ?? const Duration(seconds: 30),
        pongTimeout = pongTimeout ?? const Duration(seconds: 45);

  /// Get current heartbeat status
  HeartbeatStatus get status => _status;

  /// Get last pong received time
  DateTime? get lastPongReceived => _lastPongReceived;

  /// Get last ping sent time
  DateTime? get lastPingSent => _lastPingSent;

  /// Get number of pings sent
  int get pingsSent => _pingsSent;

  /// Get number of pongs received
  int get pongsReceived => _pongsReceived;

  /// Get number of missed pongs
  int get missedPongs => _missedPongs;

  /// Check if heartbeat is running
  bool get isRunning => _status == HeartbeatStatus.running;

  /// Get time since last pong
  Duration? get timeSinceLastPong {
    if (_lastPongReceived == null) return null;
    return DateTime.now().difference(_lastPongReceived!);
  }

  /// Start heartbeat monitoring
  ///
  /// Begins sending periodic pings and monitoring for pongs
  void start() {
    if (_status == HeartbeatStatus.running) {
      _log('Heartbeat already running');
      return;
    }

    _log(
        'Starting heartbeat (ping every ${pingInterval.inSeconds}s, timeout ${pongTimeout.inSeconds}s)');

    _status = HeartbeatStatus.running;
    _pingsSent = 0;
    _pongsReceived = 0;
    _missedPongs = 0;
    _lastPongReceived = DateTime.now(); // Initialize to now

    // Start periodic ping timer
    _pingTimer = Timer.periodic(pingInterval, (_) => _sendPing());

    // Send first ping immediately
    _sendPing();
  }

  /// Stop heartbeat monitoring
  ///
  /// Cancels all timers and resets state
  void stop() {
    if (_status == HeartbeatStatus.stopped) {
      return;
    }

    _log('Stopping heartbeat');

    _pingTimer?.cancel();
    _pingTimer = null;

    _pongTimer?.cancel();
    _pongTimer = null;

    _status = HeartbeatStatus.stopped;
  }

  /// Handle received pong message
  ///
  /// Call this when a pong message is received from the server
  void onPongReceived() {
    _lastPongReceived = DateTime.now();
    _pongsReceived++;

    // Cancel pong timeout timer
    _pongTimer?.cancel();
    _pongTimer = null;

    if (_status == HeartbeatStatus.waitingForPong) {
      _status = HeartbeatStatus.running;
      _log('Pong received ($_pongsReceived/$_pingsSent)');
    }
  }

  /// Send ping message
  void _sendPing() {
    if (_status == HeartbeatStatus.stopped) {
      return;
    }

    try {
      // Send ping message
      channel.sink.add('ping');
      _lastPingSent = DateTime.now();
      _pingsSent++;
      _status = HeartbeatStatus.waitingForPong;

      _log('Ping sent ($_pingsSent)');

      // Start pong timeout timer
      _pongTimer?.cancel();
      _pongTimer = Timer(pongTimeout, _onPongTimeout);
    } catch (e) {
      _log('Failed to send ping: $e');
      _onError(e);
    }
  }

  /// Handle pong timeout
  void _onPongTimeout() {
    _missedPongs++;
    _status = HeartbeatStatus.timeout;

    _log('Pong timeout! Missed pongs: $_missedPongs');

    // Connection is considered lost
    _onConnectionLost();
  }

  /// Handle connection lost
  void _onConnectionLost() {
    _log('Connection lost detected by heartbeat');

    // Stop heartbeat
    stop();

    // Notify callback
    if (onConnectionLost != null) {
      onConnectionLost!();
    }
  }

  /// Handle error
  void _onError(dynamic error) {
    _log('Heartbeat error: $error');

    // Treat error as connection lost
    _onConnectionLost();
  }

  /// Reset heartbeat statistics
  ///
  /// Resets counters but keeps heartbeat running
  void resetStats() {
    _pingsSent = 0;
    _pongsReceived = 0;
    _missedPongs = 0;
    _lastPongReceived = DateTime.now();
    _lastPingSent = null;
  }

  /// Get heartbeat statistics
  Map<String, dynamic> getStats() {
    return {
      'status': _status.name,
      'pingsSent': _pingsSent,
      'pongsReceived': _pongsReceived,
      'missedPongs': _missedPongs,
      'lastPingSent': _lastPingSent?.toIso8601String(),
      'lastPongReceived': _lastPongReceived?.toIso8601String(),
      'timeSinceLastPong': timeSinceLastPong?.inSeconds,
      'isHealthy': _status == HeartbeatStatus.running && _missedPongs == 0,
    };
  }

  /// Log message
  void _log(String message) {
    if (onLog != null) {
      onLog!(message);
    } else {
      debugPrint('[WebSocketHeartbeat] $message');
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}

/// Heartbeat-aware WebSocket wrapper
///
/// Wraps a WebSocket channel with automatic heartbeat monitoring
class HeartbeatWebSocket {
  final WebSocketChannel channel;
  final WebSocketHeartbeat heartbeat;
  final StreamController<dynamic> _messageController =
      StreamController<dynamic>.broadcast();
  StreamSubscription? _channelSubscription;

  HeartbeatWebSocket({
    required this.channel,
    Duration? pingInterval,
    Duration? pongTimeout,
    void Function()? onConnectionLost,
    void Function(String message)? onLog,
  }) : heartbeat = WebSocketHeartbeat(
          channel: channel,
          pingInterval: pingInterval,
          pongTimeout: pongTimeout,
          onConnectionLost: onConnectionLost,
          onLog: onLog,
        );

  /// Get message stream (excluding ping/pong messages)
  Stream<dynamic> get stream => _messageController.stream;

  /// Get sink for sending messages
  WebSocketSink get sink => channel.sink;

  /// Start heartbeat and message forwarding
  void start() {
    // Start heartbeat
    heartbeat.start();

    // Forward messages, filtering out pong responses
    _channelSubscription = channel.stream.listen(
      (message) {
        if (message == 'pong') {
          // Handle pong internally
          heartbeat.onPongReceived();
        } else {
          // Forward other messages
          _messageController.add(message);
        }
      },
      onError: (error) {
        _messageController.addError(error);
      },
      onDone: _messageController.close,
    );
  }

  /// Stop heartbeat and close streams
  Future<void> close([int? closeCode, String? closeReason]) async {
    heartbeat.stop();
    await _channelSubscription?.cancel();
    await _messageController.close();
    await channel.sink.close(closeCode, closeReason);
  }

  /// Get heartbeat statistics
  Map<String, dynamic> getHeartbeatStats() {
    return heartbeat.getStats();
  }
}
