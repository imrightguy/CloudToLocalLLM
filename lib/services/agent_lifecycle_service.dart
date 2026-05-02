import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'connection_manager_service.dart';

/// Agent lifecycle states
enum AgentLifecycleState {
  /// Agent is idle and not running
  idle,

  /// Agent is starting up
  starting,

  /// Agent is actively processing
  running,

  /// Agent is stopping
  stopping,

  /// Agent encountered an error
  error,

  /// Agent is offline/not reachable
  offline,
}

/// Agent information with lifecycle state
class AgentInfo {
  final String id;
  final String name;
  final String type;
  final AgentLifecycleState state;
  final String? activity;
  final DateTime? lastUpdate;
  final String? errorMessage;

  AgentInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.state,
    this.activity,
    this.lastUpdate,
    this.errorMessage,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['agentId'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Unknown Agent',
      type: json['type'] ?? 'custom',
      state: _parseState(json['status'] ?? json['state']),
      activity: json['activity'],
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.tryParse(json['lastUpdate'])
          : null,
      errorMessage: json['errorMessage'],
    );
  }

  static AgentLifecycleState _parseState(String status) {
    switch (status.toLowerCase()) {
      case 'idle':
        return AgentLifecycleState.idle;
      case 'starting':
        return AgentLifecycleState.starting;
      case 'running':
      case 'active':
        return AgentLifecycleState.running;
      case 'stopping':
        return AgentLifecycleState.stopping;
      case 'error':
      case 'failed':
        return AgentLifecycleState.error;
      case 'offline':
        return AgentLifecycleState.offline;
      default:
        return AgentLifecycleState.idle;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'state': state.name,
      'activity': activity,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  AgentInfo copyWith({
    String? id,
    String? name,
    String? type,
    AgentLifecycleState? state,
    String? activity,
    DateTime? lastUpdate,
    String? errorMessage,
  }) {
    return AgentInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      state: state ?? this.state,
      activity: activity ?? this.activity,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Result of an agent operation
class AgentOperationResult {
  final bool success;
  final String? message;
  final dynamic data;

  AgentOperationResult({
    required this.success,
    this.message,
    this.data,
  });

  factory AgentOperationResult.success({String? message, dynamic data}) {
    return AgentOperationResult(
      success: true,
      message: message,
      data: data,
    );
  }

  factory AgentOperationResult.failure(String message) {
    return AgentOperationResult(
      success: false,
      message: message,
    );
  }
}

/// Service for managing agent lifecycle through OpenClaw Gateway
///
/// This service communicates with OpenClaw Gateway via WebSocket to:
/// - List available agents
/// - Start/stop agents
/// - Monitor agent status
/// - Get agent logs and metrics
class AgentLifecycleService extends ChangeNotifier {
  final ConnectionManagerService _connectionManager;
  final _uuid = const Uuid();

  final Map<String, AgentInfo> _agents = {};
  final _responseCompleters = <String, Completer<Map<String, dynamic>>>{};

  bool _isLoading = false;
  String? _lastError;

  AgentLifecycleService({
    required ConnectionManagerService connectionManager,
  }) : _connectionManager = connectionManager {
    _connectionManager.addListener(_onConnectionChanged);

    // Listen for WebSocket messages
    _connectionManager.messageStream.listen(handleGatewayMessage);
  }

  /// Get all known agents
  List<AgentInfo> get agents => _agents.values.toList();

  /// Get agent by ID
  AgentInfo? getAgent(String id) => _agents[id];

  /// Loading state
  bool get isLoading => _isLoading;

  /// Last error message
  String? get lastError => _lastError;

  /// Check if service is ready (connected to OpenClaw Gateway)
  bool get isReady =>
      _connectionManager.currentBackend == BackendType.openclaw &&
      _connectionManager.isConnected &&
      _connectionManager.isGatewayHealthy();

  void _onConnectionChanged() {
    // Auto-refresh agents when connection becomes ready
    if (isReady) {
      debugPrint('[AgentLifecycle] Connection ready, refreshing agents...');
      listAgents().catchError((e) {
        debugPrint('[AgentLifecycle] Failed to auto-refresh agents: $e');
        return <AgentInfo>[];
      });
    }
    notifyListeners();
  }

  /// List all available agents from OpenClaw Gateway
  Future<List<AgentInfo>> listAgents() async {
    if (!isReady) {
      _lastError = 'Not connected to OpenClaw Gateway';
      notifyListeners();
      throw Exception(_lastError);
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[AgentLifecycle] Listing agents...');

      final requestId = _uuid.v4();
      final completer = Completer<Map<String, dynamic>>();
      _responseCompleters[requestId] = completer;

      final request = {
        'type': 'req',
        'id': requestId,
        'method': 'agent.list',
        'params': {},
      };

      _sendToGateway(request);

      final response = await completer.future.timeout(
        const Duration(seconds: 10),
      );

      _responseCompleters.remove(requestId);

      if (response['ok'] == true && response['payload'] != null) {
        final agentsList = response['payload']['agents'] as List<dynamic>?;
        if (agentsList != null) {
          for (final agentJson in agentsList) {
            final agent = AgentInfo.fromJson(agentJson as Map<String, dynamic>);
            _agents[agent.id] = agent;
          }
        }
        _lastError = null;
        debugPrint('[AgentLifecycle] ✓ Listed ${_agents.length} agents');
      } else {
        _lastError = response['error']?['message'] ?? 'Failed to list agents';
        debugPrint('[AgentLifecycle] ✗ $_lastError');
      }
    } catch (e, stack) {
      _lastError = 'Failed to list agents: $e';
      debugPrint('[AgentLifecycle] ✗ Error: $e');
      debugPrint('[AgentLifecycle] Stack: $stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return agents;
  }

  /// Start an agent
  Future<AgentOperationResult> startAgent(String agentId) async {
    if (!isReady) {
      return AgentOperationResult.failure('Not connected to OpenClaw Gateway');
    }

    try {
      debugPrint('[AgentLifecycle] Starting agent: $agentId');

      final requestId = _uuid.v4();
      final completer = Completer<Map<String, dynamic>>();
      _responseCompleters[requestId] = completer;

      final request = {
        'type': 'req',
        'id': requestId,
        'method': 'agent.start',
        'params': {
          'agentId': agentId,
        },
      };

      _sendToGateway(request);

      final response = await completer.future.timeout(
        const Duration(seconds: 30),
      );

      _responseCompleters.remove(requestId);

      if (response['ok'] == true) {
        // Update agent state
        final agent = _agents[agentId];
        if (agent != null) {
          _agents[agentId] = agent.copyWith(
            state: AgentLifecycleState.starting,
            lastUpdate: DateTime.now(),
          );
        }
        _lastError = null;
        notifyListeners();
        debugPrint('[AgentLifecycle] ✓ Agent $agentId starting');
        return AgentOperationResult.success(
          message: 'Agent started successfully',
          data: response['payload'],
        );
      } else {
        final error = response['error']?['message'] ?? 'Failed to start agent';
        _lastError = error;

        // Update agent to error state
        final agent = _agents[agentId];
        if (agent != null) {
          _agents[agentId] = agent.copyWith(
            state: AgentLifecycleState.error,
            errorMessage: error,
            lastUpdate: DateTime.now(),
          );
        }
        notifyListeners();

        debugPrint('[AgentLifecycle] ✗ Failed to start $agentId: $error');
        return AgentOperationResult.failure(error);
      }
    } catch (e) {
      _lastError = 'Failed to start agent: $e';
      debugPrint('[AgentLifecycle] ✗ Error starting $agentId: $e');
      notifyListeners();
      return AgentOperationResult.failure(_lastError!);
    }
  }

  /// Stop an agent
  Future<AgentOperationResult> stopAgent(String agentId) async {
    if (!isReady) {
      return AgentOperationResult.failure('Not connected to OpenClaw Gateway');
    }

    try {
      debugPrint('[AgentLifecycle] Stopping agent: $agentId');

      final requestId = _uuid.v4();
      final completer = Completer<Map<String, dynamic>>();
      _responseCompleters[requestId] = completer;

      final request = {
        'type': 'req',
        'id': requestId,
        'method': 'agent.stop',
        'params': {
          'agentId': agentId,
        },
      };

      _sendToGateway(request);

      final response = await completer.future.timeout(
        const Duration(seconds: 30),
      );

      _responseCompleters.remove(requestId);

      if (response['ok'] == true) {
        // Update agent state
        final agent = _agents[agentId];
        if (agent != null) {
          _agents[agentId] = agent.copyWith(
            state: AgentLifecycleState.stopping,
            lastUpdate: DateTime.now(),
          );
        }
        _lastError = null;
        notifyListeners();
        debugPrint('[AgentLifecycle] ✓ Agent $agentId stopping');
        return AgentOperationResult.success(
          message: 'Agent stopped successfully',
          data: response['payload'],
        );
      } else {
        final error = response['error']?['message'] ?? 'Failed to stop agent';
        _lastError = error;
        debugPrint('[AgentLifecycle] ✗ Failed to stop $agentId: $error');
        return AgentOperationResult.failure(error);
      }
    } catch (e) {
      _lastError = 'Failed to stop agent: $e';
      debugPrint('[AgentLifecycle] ✗ Error stopping $agentId: $e');
      notifyListeners();
      return AgentOperationResult.failure(_lastError!);
    }
  }

  /// Restart an agent
  Future<AgentOperationResult> restartAgent(String agentId) async {
    final stopResult = await stopAgent(agentId);
    if (!stopResult.success) {
      return stopResult;
    }

    // Wait a moment for the agent to stop
    await Future.delayed(const Duration(seconds: 2));

    return await startAgent(agentId);
  }

  /// Get agent status
  Future<AgentInfo?> getAgentStatus(String agentId) async {
    if (!isReady) {
      _lastError = 'Not connected to OpenClaw Gateway';
      return null;
    }

    try {
      debugPrint('[AgentLifecycle] Getting status for: $agentId');

      final requestId = _uuid.v4();
      final completer = Completer<Map<String, dynamic>>();
      _responseCompleters[requestId] = completer;

      final request = {
        'type': 'req',
        'id': requestId,
        'method': 'agent.status',
        'params': {
          'agentId': agentId,
        },
      };

      _sendToGateway(request);

      final response = await completer.future.timeout(
        const Duration(seconds: 10),
      );

      _responseCompleters.remove(requestId);

      if (response['ok'] == true && response['payload'] != null) {
        final agent = AgentInfo.fromJson(response['payload']);
        _agents[agentId] = agent;
        _lastError = null;
        notifyListeners();
        return agent;
      } else {
        _lastError =
            response['error']?['message'] ?? 'Failed to get agent status';
        debugPrint('[AgentLifecycle] ✗ $_lastError');
        return null;
      }
    } catch (e) {
      _lastError = 'Failed to get agent status: $e';
      debugPrint('[AgentLifecycle] ✗ Error: $e');
      notifyListeners();
      return null;
    }
  }

  /// Send request to OpenClaw Gateway via WebSocket
  void _sendToGateway(Map<String, dynamic> request) {
    debugPrint('[AgentLifecycle] Sending request: ${request['method']}');

    try {
      final jsonRequest = jsonEncode(request);
      final wsChannel = _connectionManager
          .wsChannel; // I need to expose this or add a send method

      if (wsChannel != null) {
        wsChannel.sink.add(jsonRequest);
      } else {
        debugPrint(
            '[AgentLifecycle] ✗ Cannot send request: WebSocket not connected');
      }
    } catch (e) {
      debugPrint('[AgentLifecycle] ✗ Error encoding/sending request: $e');
    }
  }

  /// Handle incoming WebSocket messages from OpenClaw Gateway
  void handleGatewayMessage(Map<String, dynamic> message) {
    if (message['type'] == 'res' && message['id'] != null) {
      final requestId = message['id'] as String;
      final completer = _responseCompleters[requestId];
      if (completer != null && !completer.isCompleted) {
        completer.complete(message);
      }
    } else if (message['type'] == 'event' &&
        message['event'] == 'agent.status') {
      // Handle agent status update events
      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload != null && payload['agentId'] != null) {
        final agent = AgentInfo.fromJson(payload);
        _agents[agent.id] = agent;
        notifyListeners();
        debugPrint(
            '[AgentLifecycle] Agent status updated: ${agent.name} - ${agent.state}');
      }
    }
  }

  /// Refresh all agents from OpenClaw Gateway
  Future<void> refreshAgents() async {
    await listAgents();
  }

  @override
  void dispose() {
    _connectionManager.removeListener(_onConnectionChanged);
    // Cancel all pending completers
    for (final completer in _responseCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Service disposed'));
      }
    }
    _responseCompleters.clear();
    super.dispose();
  }
}
