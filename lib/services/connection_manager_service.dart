import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'tunnel_service.dart';
import 'streaming_service.dart';
import 'cloud_streaming_service.dart';
import 'auth_service.dart';
import '../models/llm_communication_error.dart';
import '../utils/logger.dart';
import '../config/app_config.dart';

enum ConnectionType { none, local, cloud }
enum GatewayHealthStatus { unknown, healthy, unhealthy, connecting, error }

/// Connection Manager Service - manages connections to LLM providers
/// Standardized on OpenClaw Gateway as the sole provider.
class ConnectionManagerService extends ChangeNotifier {
  final TunnelService _tunnelService;
  final AuthService _authService;

  String? _selectedModel;
  CloudStreamingService? _cloudStreamingService;
  List<String> _availableModels = [];
  WebSocketChannel? _wsChannel;
  bool _isConnected = false;
  GatewayHealthStatus _healthStatus = GatewayHealthStatus.unknown;
  String? _lastError;
  DateTime? _lastSuccessfulConnection;
  final _responseCompleters = <String, Completer<String>>{};
  final _runIdToCompleter = <String, String>{}; // runId -> requestId mapping

  ConnectionManagerService({
    required TunnelService tunnelService,
    required AuthService authService,
  })  : _tunnelService = tunnelService,
        _authService = authService {
    _tunnelService.addListener(_onConnectionChanged);
    _authService.addListener(_onAuthChanged);
  }

  bool get isConnected => _isConnected;
  GatewayHealthStatus get healthStatus => _healthStatus;
  String? get lastError => _lastError;
  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;

  bool get hasLocalConnection =>
      true; // Force true since we standardized on OpenClaw
  bool get hasCloudConnection => _tunnelService.isConnected;
  bool get hasAnyConnection => true;
  String? get selectedModel => _selectedModel;
  List<String> get availableModels => _availableModels;

  ConnectionType getBestConnectionType() {
    return ConnectionType.local; // Always prefer local OpenClaw Gateway
  }

  StreamingService? getStreamingService() {
    final connectionType = getBestConnectionType();
    switch (connectionType) {
      case ConnectionType.local:
        _cloudStreamingService ??= CloudStreamingService(
          baseUrl: AppConfig.defaultGatewayUrl,
          authService: _authService,
        );
        return _cloudStreamingService;
      case ConnectionType.cloud:
        _cloudStreamingService ??= CloudStreamingService(
          authService: _authService,
        );
        if (!_cloudStreamingService!.connection.isActive) {
          _cloudStreamingService!.establishConnection().catchError((e) {
            appLogger.warning(
              '[ConnectionManager] Cloud streaming connection failed: $e',
            );
          });
        }
        return _cloudStreamingService;
      default:
        return null;
    }
  }

  Future<String?> sendChatMessage({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    if (!_isConnected) {
      await _connectWebSocket();
    }

    if (!_isConnected) {
      throw LLMCommunicationError.providerNotFound();
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<String>();
    _responseCompleters[id] = completer;

    // Use correct OpenClaw chat.send protocol
    final request = {
      'type': 'req',
      'id': id,
      'method': 'chat.send',
      'params': {
        'sessionKey': 'cloudtolocalllm',
        'message': message,
        'idempotencyKey': 'chat-$id',
      }
    };

    _wsChannel?.sink.add(jsonEncode(request));

    try {
      return await completer.future.timeout(const Duration(seconds: 120));
    } catch (e) {
      _responseCompleters.remove(id);
      rethrow;
    }
  }

  Future<void> _connectWebSocket() async {
    if (_wsChannel != null && _isConnected) return;

    final wsUrl = AppConfig.defaultGatewayUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    _healthStatus = GatewayHealthStatus.connecting;
    _lastError = null;
    notifyListeners();

    try {
      debugPrint('[ConnectionManager] Connecting to WebSocket: $wsUrl');
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/'));

      await _wsChannel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('WebSocket connection timed out after 10 seconds');
        },
      );

      // Listen for responses in background
      _wsChannel!.stream.listen(
        (data) => _handleWebSocketMessage(data.toString()),
        onError: (e) {
          final error = 'WebSocket error: $e';
          debugPrint('[ConnectionManager] $error');
          appLogger.error('[ConnectionManager] WebSocket error', error: e);
          _isConnected = false;
          _healthStatus = GatewayHealthStatus.error;
          _lastError = error;
          notifyListeners();
        },
        onDone: () {
          debugPrint('[ConnectionManager] WebSocket closed');
          _isConnected = false;
          _healthStatus = GatewayHealthStatus.unhealthy;
          notifyListeners();
        },
      );

      // Do handshake
      await _performHandshake();
      _isConnected = true;
      _healthStatus = GatewayHealthStatus.healthy;
      _lastSuccessfulConnection = DateTime.now();
      _lastError = null;
      debugPrint('[ConnectionManager] ✓ WebSocket connected to OpenClaw Gateway');
      notifyListeners();
    } catch (e, stack) {
      final error = 'WebSocket connection failed: $e';
      debugPrint('[ConnectionManager] ✗ $error');
      debugPrint('[ConnectionManager] Stack trace: $stack');
      appLogger.error('[ConnectionManager] Connection failed', error: e, stackTrace: stack);
      _isConnected = false;
      _healthStatus = GatewayHealthStatus.error;
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _performHandshake() async {
    final token = await _authService.getAccessToken() ?? '';
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final connectRequest = {
      'type': 'req',
      'id': id,
      'method': 'connect',
      'params': {
        'minProtocol': 3,
        'maxProtocol': 3,
        'client': {
          'id': 'cloudtolocalllm',
          'version': '10.1.187',
          'platform': 'linux',
          'mode': 'operator'
        },
        'role': 'operator',
        'scopes': ['operator.read', 'operator.write'],
        'auth': {'token': token},
        'locale': 'en-US',
        'userAgent': 'CloudToLocalLLM/10.1.187',
      }
    };

    _wsChannel?.sink.add(jsonEncode(connectRequest));

    // Wait for hello-ok by listening once with timeout
    try {
      final handshakeResult = await _wsChannel!.stream
          .take(5)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: (sink) {
              sink.addError(TimeoutException('Handshake timed out after 10 seconds'));
              sink.close();
            },
          )
          .first;

      final msg = jsonDecode(handshakeResult as String);
      if (msg['type'] == 'res' && msg['payload']?['type'] == 'hello-ok') {
        debugPrint('[ConnectionManager] ✓ Handshake successful');
      } else if (msg['type'] == 'res' && msg['ok'] == false) {
        final error = msg['error']?['message'] ?? 'Handshake failed';
        throw Exception('Handshake rejected: $error');
      }
    } catch (e, stack) {
      debugPrint('[ConnectionManager] ✗ Handshake error: $e');
      appLogger.error('[ConnectionManager] Handshake failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  void _handleWebSocketMessage(String data) {
    final msg = jsonDecode(data);
    
    // Handle chat response (acknowledgment with runId)
    if (msg['type'] == 'res' && msg['id'] != null) {
      final completer = _responseCompleters[msg['id']];
      if (completer != null && !completer.isCompleted) {
        if (msg['ok'] == true) {
          // chat.send returns runId, not the response yet
          // Keep completer open for chat event with state='final'
          final runId = msg['payload']?['runId'];
          if (runId != null) {
            // Store runId -> completer mapping for event handling
            _runIdToCompleter[runId] = msg['id'];
          }
        } else {
          _responseCompleters.remove(msg['id']);
          completer.completeError(Exception(msg['error']?['message'] ?? 'Unknown error'));
        }
      }
    }
    
    // Handle chat events (final message delivery)
    if (msg['type'] == 'event' && msg['event'] == 'chat') {
      final payload = msg['payload'] as Map<String, dynamic>?;
      final runId = payload?['runId'] as String?;
      final state = payload?['state'] as String?;
      
      if (runId != null && state == 'final') {
        final reqId = _runIdToCompleter.remove(runId);
        final completer = reqId != null ? _responseCompleters.remove(reqId) : null;
        if (completer != null && !completer.isCompleted) {
          final message = payload?['message'] as Map<String, dynamic>?;
          final content = message?['content'] as List?;
          if (content != null) {
            final textBuffer = StringBuffer();
            for (final block in content) {
              if (block is Map && block['type'] == 'text') {
                textBuffer.write(block['text'] ?? '');
              }
            }
            completer.complete(textBuffer.toString());
          } else {
            completer.complete('');
          }
        }
      } else if (state == 'error') {
        final reqId = runId != null ? _runIdToCompleter.remove(runId) : null;
        final completer = reqId != null ? _responseCompleters.remove(reqId) : null;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(Exception(payload?['errorMessage'] ?? 'Chat error'));
        }
      }
    }
  }

  Future<void> initialize() async {
    await testConnection();
    if (_authService.isAuthenticated.value) {
      try {
        await _tunnelService.connect();
      } catch (e) {
        debugPrint('[ConnectionManager] Tunnel connection failed: $e');
      }
    }
    _autoSelectModel();
    notifyListeners();
  }

  Future<void> testConnection() async {
    debugPrint(
        '[ConnectionManager] Testing WebSocket connection to ${AppConfig.defaultGatewayUrl}...');

    try {
      await _connectWebSocket();

      if (_isConnected) {
        _availableModels = [];
        debugPrint('[ConnectionManager] ✓ OpenClaw WebSocket verified and ready');
      } else {
        _availableModels = [];
        debugPrint('[ConnectionManager] ✗ WebSocket connection failed');
      }
    } catch (e, stack) {
      debugPrint('[ConnectionManager] ✗ Connection test exception: $e');
      appLogger.error('[ConnectionManager] Connection test failed', error: e, stackTrace: stack);
      _availableModels = [];
      _healthStatus = GatewayHealthStatus.unhealthy;
      _lastError = e.toString();
    }
    notifyListeners();
  }

  /// Check if OpenClaw Gateway is healthy
  /// Returns true if connected and recently active
  bool isGatewayHealthy() {
    if (!_isConnected || _healthStatus != GatewayHealthStatus.healthy) {
      return false;
    }

    // Consider unhealthy if no activity for 5 minutes
    if (_lastSuccessfulConnection != null) {
      final timeSinceLastConnection = DateTime.now().difference(_lastSuccessfulConnection!);
      if (timeSinceLastConnection > const Duration(minutes: 5)) {
        _healthStatus = GatewayHealthStatus.unhealthy;
        notifyListeners();
        return false;
      }
    }

    return true;
  }

  /// Get detailed gateway status for UI display
  Map<String, dynamic> getGatewayStatus() {
    return {
      'isConnected': _isConnected,
      'healthStatus': _healthStatus.name,
      'lastError': _lastError,
      'lastSuccessfulConnection': _lastSuccessfulConnection?.toIso8601String(),
      'endpoint': AppConfig.defaultGatewayUrl,
    };
  }

  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  Future<void> reconnectAll() async {
    await testConnection();
    if (!_tunnelService.isConnected) {
      try {
        await _tunnelService.connect();
      } catch (e) {
        debugPrint('[ConnectionManager] Tunnel reconnection failed: $e');
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> getConnectionStatus() {
    return {
      'local': {'connected': hasLocalConnection, 'models': _availableModels},
      'cloud': {'connected': hasCloudConnection},
      'active': getBestConnectionType().name,
      'selectedModel': _selectedModel,
    };
  }

  void _autoSelectModel() {
    if (_selectedModel != null) return;
    if (_availableModels.isNotEmpty) {
      setSelectedModel(_availableModels.first);
    }
  }

  void _onConnectionChanged() {
    _autoSelectModel();
    notifyListeners();
  }

  void _onAuthChanged() {
    if (_authService.isAuthenticated.value) {
      if (!_tunnelService.isConnected) {
        _tunnelService.connect().catchError((e) {
          debugPrint(
              '[ConnectionManager] Tunnel connection failed on auth change: $e');
        });
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tunnelService.removeListener(_onConnectionChanged);
    _authService.removeListener(_onAuthChanged);
    _cloudStreamingService?.dispose();
    super.dispose();
  }
}
