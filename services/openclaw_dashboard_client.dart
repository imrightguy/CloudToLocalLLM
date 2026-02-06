/// OpenClaw Dashboard Client Service
///
/// Manages WebSocket connection to OpenClaw's agent dashboard.
/// Mirrors agent status, lists, and lifecycle events in real-time.
///
/// Features:
/// - WebSocket connection with automatic reconnection
/// - Agent status monitoring (online/offline/error)
/// - Agent lifecycle management (spawn, monitor, terminate)
/// - Dashboard configuration mirroring
/// - Real-time event streaming
library;

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OpenClaw dashboard connection settings
class OpenClawDashboardSettings {
  final String baseUrl;
  final String token;
  final Duration reconnectInterval;
  final Duration connectionTimeout;

  const OpenClawDashboardSettings({
    required this.baseUrl,
    required this.token,
    this.reconnectInterval = const Duration(seconds: 30),
    this.connectionTimeout = const Duration(seconds: 10),
  });

  factory OpenClawDashboardSettings.fromPreferences(SharedPreferences prefs) {
    return OpenClawDashboardSettings(
      baseUrl: prefs.getString('openclaw_dashboard_url') ?? 'ws://localhost:18789',
      token: prefs.getString('openclaw_dashboard_token') ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'token': token,
      'reconnectInterval': reconnectInterval.inSeconds,
      'connectionTimeout': connectionTimeout.inSeconds,
    };
  }
}

/// Dashboard connection state
enum DashboardConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Dashboard connection event
class DashboardConnectionEvent {
  final DashboardConnectionState state;
  final DateTime timestamp;
  final String? error;

  const DashboardConnectionEvent({
    required this.state,
    required this.timestamp,
    this.error,
  });

  DashboardConnectionEvent copyWith({DashboardConnectionState? state, String? error}) {
    return DashboardConnectionEvent(
      state: state ?? this.state,
      timestamp: DateTime.now(),
      error: error,
    );
  }
}

/// Agent status information
class AgentStatus {
  final String id;
  final String name;
  final String status; // online, offline, error
  final DateTime lastSeen;
  final Map<String, dynamic>? metadata;

  const AgentStatus({
    required this.id,
    required this.name,
    required this.status,
    required this.lastSeen,
    this.metadata,
  });

  factory AgentStatus.fromJson(Map<String, dynamic> json) {
    return AgentStatus(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'lastSeen': lastSeen.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Agent lifecycle event
enum AgentLifecycleEventType {
  spawned,
  statusChanged,
  terminated,
  error,
}

class AgentLifecycleEvent {
  final String agentId;
  final AgentLifecycleEventType type;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  const AgentLifecycleEvent({
    required this.agentId,
    required this.type,
    required this.timestamp,
    this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'agentId': agentId,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }
}

/// OpenClaw dashboard service
class OpenClawDashboardService extends ChangeNotifier {
  static const String _settingsKey = 'openclaw_dashboard';
  static const String _connectionStateKey = 'openclaw_connection';
  static const String _agentStatusKey = 'openclaw_agent_status';

  final OpenClawDashboardSettings _settings;
  DashboardConnectionState _connectionState = DashboardConnectionState.disconnected;
  final List<DashboardConnectionEvent> _connectionEvents = [];
  final Map<String, AgentStatus> _agentStatuses = {};
  final List<AgentLifecycleEvent> _lifecycleEvents = [];

  WebSocketChannel? _wsChannel;
  bool _isConnecting = false;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  // Stream controllers
  final StreamController<DashboardConnectionEvent> _connectionEventsController =
      StreamController<DashboardConnectionEvent>.broadcast();
  final StreamController<AgentLifecycleEvent> _lifecycleEventsController =
      StreamController<AgentLifecycleEvent>.broadcast();

  OpenClawDashboardService()
      : _settings = OpenClawDashboardSettings.fromPreferences(
          SharedPreferences.getInstance());

  /// Get current connection state
  DashboardConnectionState get connectionState => _connectionState;

  /// Get agent statuses
  Map<String, AgentStatus> get agentStatuses => Map.from(_agentStatuses);

  /// Get connection events stream
  Stream<DashboardConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;

  /// Get lifecycle events stream
  Stream<AgentLifecycleEvent> get lifecycleEvents => _lifecycleEventsController.stream;

  /// Connect to OpenClaw dashboard WebSocket
  Future<void> connect() async {
    if (_isConnecting || _connectionState == DashboardConnectionState.connected) {
      return;
    }

    _setConnectionState(DashboardConnectionState.connecting);
    _addConnectionEvent(DashboardConnectionEvent(
          state: DashboardConnectionState.connecting,
          timestamp: DateTime.now(),
        ));

    try {
      _wsChannel = WebSocketChannel.connect(_settings.baseUrl);

      // Handle connection established
      _wsChannel!.ready.then((_) {
        _setConnectionState(DashboardConnectionState.connected);
        _addConnectionEvent(DashboardConnectionEvent(
              state: DashboardConnectionState.connected,
              timestamp: DateTime.now(),
            ));

        // Start heartbeat
        _startHeartbeat();

        // Request initial agent list
        _sendMessage({
          'type': 'list_agents',
        });
      });

      // Handle errors
      _wsChannel!.stream.handleError((error) {
        _setConnectionState(DashboardConnectionState.error);
        _addConnectionEvent(DashboardConnectionEvent(
              state: DashboardConnectionState.error,
              timestamp: DateTime.now(),
              error: error.toString(),
            ));

        // Schedule reconnection
        if (!_isReconnecting) {
          _isReconnecting = true;
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(_settings.reconnectInterval, () {
            _isReconnecting = false;
            connect();
          });
        }
      });

      // Handle incoming messages
      _wsChannel!.stream.listen((message) {
        _handleIncomingMessage(message);
      });

      notifyListeners();
    } catch (e) {
      _setConnectionState(DashboardConnectionState.error);
      _addConnectionEvent(DashboardConnectionEvent(
            state: DashboardConnectionState.error,
            timestamp: DateTime.now(),
            error: e.toString(),
          ));

      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Disconnect from dashboard
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    await _wsChannel?.sink.close();
    _setConnectionState(DashboardConnectionState.disconnected);

    _addConnectionEvent(DashboardConnectionEvent(
          state: DashboardConnectionState.disconnected,
          timestamp: DateTime.now(),
        ));

    _wsChannel = null;
    notifyListeners();
  }

  /// Send message to dashboard
  void _sendMessage(Map<String, dynamic> message) {
    if (_wsChannel != null && _connectionState == DashboardConnectionState.connected) {
      try {
        _wsChannel!.sink.add(jsonEncode(message));
      } catch (e) {
        // Silent fail
      }
    }
  }

  /// Handle incoming WebSocket message
  void _handleIncomingMessage(dynamic message) {
    if (message is! Map) {
      return;
    }

    final msgMap = message as Map<String, dynamic>;
    final type = msgMap['type'];

    switch (type) {
      case 'agents':
        _handleAgentList(msgMap);
        break;
      case 'agent_status':
        _handleAgentStatus(msgMap);
        break;
      case 'agent_event':
        _handleAgentEvent(msgMap);
        break;
      case 'heartbeat':
        // Ignore heartbeat
        break;
      case 'error':
        _handleErrorMessage(msgMap);
        break;
    }
  }

  /// Handle agent list message
  void _handleAgentList(Map<String, dynamic> message) {
    final agents = message['agents'] as List<dynamic>?;

    if (agents == null) {
      return;
    }

    final newStatuses = <String, AgentStatus>{};

    for (final agent in agents) {
      if (agent is Map) {
        final agentJson = agent as Map<String, dynamic>;
        final id = agentJson['id'] as String;

        // Update existing status
        if (_agentStatuses.containsKey(id)) {
          final existing = _agentStatuses[id]!;
          final existingStatus = AgentStatus.fromJson(existing.toJson());

          final newStatus = AgentStatus.fromJson(agentJson);

          if (existingStatus.status != newStatus.status) {
            newStatuses[id] = newStatus;
            _lifecycleEvents.add(AgentLifecycleEvent(
                  agentId: id,
                  type: AgentLifecycleEventType.statusChanged,
                  timestamp: DateTime.now(),
                  details: {'oldStatus': existingStatus.status, 'newStatus': newStatus.status},
                ));
          }
        } else {
          // New agent
          newStatuses[id] = AgentStatus.fromJson(agentJson);
          _lifecycleEvents.add(AgentLifecycleEvent(
                agentId: id,
                type: AgentLifecycleEventType.spawned,
                timestamp: DateTime.now(),
              ));
        }
      }
    }

    _agentStatuses = newStatuses;
    notifyListeners();
  }

  /// Handle agent status update
  void _handleAgentStatus(Map<String, dynamic> message) {
    final agent = message['agent'] as Map<String, dynamic>?;

    if (agent == null) {
      return;
    }

    final agentJson = agent as Map<String, dynamic>;
    final id = agentJson['id'] as String;
    final newStatus = AgentStatus.fromJson(agentJson);

    // Update or add status
    if (_agentStatuses.containsKey(id)) {
      final existing = _agentStatuses[id]!;
      final existingStatus = AgentStatus.fromJson(existing.toJson());

      _lifecycleEvents.add(AgentLifecycleEvent(
            agentId: id,
            type: AgentLifecycleEventType.statusChanged,
            timestamp: DateTime.now(),
            details: {'oldStatus': existingStatus.status, 'newStatus': newStatus.status},
          ));
    } else {
      _lifecycleEvents.add(AgentLifecycleEvent(
            agentId: id,
            type: AgentLifecycleEventType.spawned,
            timestamp: DateTime.now(),
          ));
    }

    _agentStatuses[id] = newStatus;
    notifyListeners();
  }

  /// Handle agent event (spawn, terminate, etc)
  void _handleAgentEvent(Map<String, dynamic> message) {
    final event = message['event'] as Map<String, dynamic>?;
    final agentId = event?['agentId'] as String?;

    if (agentId == null) {
      return;
    }

    final eventTypeStr = event?['type'] as String?;

    switch (eventTypeStr) {
      case 'spawned':
        _lifecycleEvents.add(AgentLifecycleEvent(
              agentId: agentId,
              type: AgentLifecycleEventType.spawned,
              timestamp: DateTime.now(),
              details: event,
            ));
        break;
      case 'terminated':
        _lifecycleEvents.add(AgentLifecycleEvent(
              agentId: agentId,
              type: AgentLifecycleEventType.terminated,
              timestamp: DateTime.now(),
              details: event,
            ));
        break;
      case 'error':
        _lifecycleEvents.add(AgentLifecycleEvent(
              agentId: agentId,
              type: AgentLifecycleEventType.error,
              timestamp: DateTime.now(),
              details: event,
            ));
        break;
    }

    notifyListeners();
  }

  /// Handle error message from server
  void _handleErrorMessage(Map<String, dynamic> message) {
    _addConnectionEvent(DashboardConnectionEvent(
          state: DashboardConnectionState.error,
          timestamp: DateTime.now(),
          error: message['error'] as String?,
        ));
  }

  /// Set connection state
  void _setConnectionState(DashboardConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  /// Add connection event
  void _addConnectionEvent(DashboardConnectionEvent event) {
    _connectionEvents.add(event);

    // Keep only last 100 events
    if (_connectionEvents.length > 100) {
      _connectionEvents.removeRange(0, _connectionEvents.length - 100);
    }

    notifyListeners();
  }

  /// Start heartbeat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connectionState == DashboardConnectionState.connected) {
        _sendMessage({
          'type': 'heartbeat',
        });
      }
    });
  }

  /// Spawn an agent
  Future<void> spawnAgent(Map<String, dynamic> config) async {
    _sendMessage({
      'type': 'spawn_agent',
      'config': config,
    });
  }

  /// Terminate an agent
  Future<void> terminateAgent(String agentId) async {
    _sendMessage({
      'type': 'terminate_agent',
      'agentId': agentId,
    });
  }

  /// Dispose
  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    disconnect();

    _connectionEventsController.close();
    _lifecycleEventsController.close();

    super.dispose();
  }

  /// Get connection history
  List<DashboardConnectionEvent> getConnectionHistory() {
    return List.from(_connectionEvents);
  }

  /// Get lifecycle history
  List<AgentLifecycleEvent> getLifecycleHistory() {
    return List.from(_lifecycleEvents);
  }

  /// Clear history
  void clearHistory() {
    _connectionEvents.clear();
    _lifecycleEvents.clear();
    _agentStatuses.clear();
    notifyListeners();
  }

  /// Update settings
  Future<void> updateSettings(OpenClawDashboardSettings newSettings) async {
    _settings = newSettings;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openclaw_dashboard_url', newSettings.baseUrl);
    await prefs.setString('openclaw_dashboard_token', newSettings.token);

    // Reconnect with new settings
    await disconnect();

    if (newSettings.baseUrl.isNotEmpty) {
      connect();
    }
  }

  /// Export status
  Map<String, dynamic> exportStatus() {
    return {
      'connectionState': _connectionState.name,
      'connectionStateTimestamp':
          _connectionEvents.isNotEmpty ? _connectionEvents.last.timestamp : null,
      'agents': _agentStatuses.values.map((status) => status.toJson()).toList(),
      'connectionEvents': _connectionEvents.map((event) => event.toJson()).toList(),
      'lifecycleEvents': _lifecycleEvents.map((event) => event.toJson()).toList(),
    };
  }

  /// Check if dashboard is available
  bool get isAvailable => _connectionState == DashboardConnectionState.connected;

  /// Get connection uptime
  Duration getConnectionUptime() {
    if (_connectionEvents.isEmpty) {
      return Duration.zero;
    }

    // Find last connected event
    final connectedEvents = _connectionEvents
        .where((e) => e.state == DashboardConnectionState.connected)
        .toList();

    if (connectedEvents.isEmpty) {
      return Duration.zero;
    }

    // Calculate uptime from last connected event
    final lastConnected = connectedEvents.last;
    return DateTime.now().difference(lastConnected.timestamp);
  }
}
