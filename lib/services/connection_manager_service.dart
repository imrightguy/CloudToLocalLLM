import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'cloud_streaming_service.dart';
import 'hermes_manager/hermes_manager.dart';
import 'openclaw_manager/gateway_control_service.dart';
import 'streaming_service.dart';

final Logger _log = Logger('ConnectionManagerService');

/// Supported backend types.
enum BackendType {
  openclaw,
  hermes,
}

/// Connection type preference (used by UI).
enum ConnectionType {
  local,
  hermes,
  openclaw,
}

/// Manages connections to different backend gateways (OpenClaw, Hermes, etc.).
///
/// This service allows switching between different LLM gateway backends.
/// Extends [ChangeNotifier] so UI layers can reactively observe state.
class ConnectionManagerService extends ChangeNotifier {
  /// The current backend type.
  BackendType get currentBackend => _currentBackend;
  BackendType _currentBackend = BackendType.openclaw;

  /// The OpenClaw gateway control service.
  final GatewayControlService openclawGatewayService;

  /// The Hermes gateway control service.
  final HermesGatewayControlService hermesGatewayService;

  /// The OpenClaw streaming service (for WebSocket connections).
  CloudStreamingService? _openclawStreamingService;

  /// The Hermes streaming service.
  HermesStreamingService? _hermesStreamingService;

  // ---------------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------------
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool get hasCloudConnection =>
      _isConnected && _currentBackend != BackendType.hermes;

  // ---------------------------------------------------------------------------
  // Model management
  // ---------------------------------------------------------------------------
  List<String> _availableModels = [];
  List<String> get availableModels => _availableModels;

  String? _selectedModel;
  String? get selectedModel => _selectedModel;
  String? get activeProviderModelId => _selectedModel;

  void setAvailableModels(List<String> models) {
    _availableModels = models.toSet().toList(growable: false);
    if (_availableModels.isNotEmpty &&
        (_selectedModel == null || !_availableModels.contains(_selectedModel))) {
      _selectedModel = _availableModels.first;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Gateway token
  // ---------------------------------------------------------------------------
  String? _gatewayToken;
  String? get gatewayToken => _gatewayToken;

  Future<void> loadGatewayToken() async {
    try {
      final url = Uri.parse('http://127.0.0.1:8080/api/gateway/token');
      final client = HttpClient();
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        _gatewayToken = data['token'] as String?;
      }
      client.close();
    } catch (e) {
      _log.warning('Failed to load gateway token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Error / health tracking
  // ---------------------------------------------------------------------------
  String? _lastError;
  String? get lastError => _lastError;

  DateTime? _lastSuccessfulConnection;
  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;

  String? get healthStatus =>
      _isConnected ? 'healthy' : 'disconnected';

  // ---------------------------------------------------------------------------
  // Connection type / backend info
  // ---------------------------------------------------------------------------
  String? get preferredConnectionType =>
      _currentBackend == BackendType.hermes ? 'hermes' : 'local';

  BackendType? get activeBackend => _currentBackend;

  // ---------------------------------------------------------------------------
  // WebSocket access (for agent_lifecycle_service)
  // ---------------------------------------------------------------------------
  WebSocketChannel? get wsChannel => _activeWsChannel;

  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _activeWsChannel;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  ConnectionManagerService({
    required this.openclawGatewayService,
    required this.hermesGatewayService,
  });

  // ---------------------------------------------------------------------------
  // Existing API: connect
  // ---------------------------------------------------------------------------
  Stream<Map<String, dynamic>> connect({
    String? hermesUrl,
    String? hermesApiKey,
    String? model,
  }) {
    switch (_currentBackend) {
      case BackendType.openclaw:
        return _connectToOpenClaw();
      case BackendType.hermes:
        return _connectToHermes(hermesUrl, hermesApiKey, model ?? 'hermes/model');
    }
  }

  Stream<Map<String, dynamic>> _connectToOpenClaw() {
    _log.info('Connecting to OpenClaw gateway');
    // Stub — delegates to openclaw gateway service when implemented
    _isConnected = true;
    _lastSuccessfulConnection = DateTime.now();
    _lastError = null;
    notifyListeners();
    return const Stream.empty();
  }

  Stream<Map<String, dynamic>> _connectToHermes(
    String? hermesUrl,
    String? hermesApiKey,
    String model,
  ) {
    _log.info('Connecting to Hermes gateway');
    _hermesStreamingService = HermesStreamingService(
      baseUrl: hermesUrl ?? 'ws://localhost',
      port: 1337,
      model: model,
      apiKey: hermesApiKey ?? '',
    );

    try {
      _hermesStreamingService!.connect();
      // Store a reference to the ws channel for agent_lifecycle_service
      // The hermes_manager HermesStreamingService manages its own channel internally.
      _isConnected = true;
      _lastSuccessfulConnection = DateTime.now();
      _lastError = null;
      notifyListeners();

      // Pipe response stream into messageStream
      _hermesStreamingService!.responseStream.listen(
        _messageStreamController.add,
        onError: (Object e) {
          _log.severe('Hermes stream error', e);
          _messageStreamController.addError(e);
        },
      );

      return _hermesStreamingService!.responseStream;
    } catch (e, st) {
      _log.severe('Failed to connect to Hermes', e, st);
      _isConnected = false;
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Existing API: switchBackend / getBackend / close / initialize
  // ---------------------------------------------------------------------------
  void switchBackend(BackendType newBackend) {
    _log.info('Switching backend from $_currentBackend to $newBackend');
    close();
    _currentBackend = newBackend;
    notifyListeners();
  }

  BackendType getBackend() => _currentBackend;

  void close() {
    _hermesStreamingService?.close();
    _openclawStreamingService?.closeConnection();
    _activeWsChannel = null;
    _isConnected = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    _log.info('Initializing ConnectionManagerService');
    _isConnected = false;
    _availableModels = [];
    _selectedModel = null;
    _lastError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // New API methods
  // ---------------------------------------------------------------------------

  Future<bool> testConnection() async {
    try {
      if (_currentBackend == BackendType.hermes) {
        final service = HermesStreamingService(
          baseUrl: 'ws://localhost',
          port: 1337,
          model: 'test',
          apiKey: '',
        );
        await service.connect();
        unawaited(service.close());
      } else {
        await openclawGatewayService.checkStatus();
      }
      _isConnected = true;
      _lastSuccessfulConnection = DateTime.now();
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic> getGatewayStatus() {
    final status = openclawGatewayService.state;
    return {
      'state': status.name,
      'isRunning': status == GatewayState.running,
      'isConnected': _isConnected,
      'backend': _currentBackend.name,
    };
  }

  bool isGatewayHealthy() {
    return _isConnected && openclawGatewayService.isRunning;
  }

  Future<void> reconnectAll() async {
    _log.info('Reconnecting all services');
    try {
      connect();
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<String?> sendChatMessage({
    required String model,
    required String message,
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      final stream = connect(model: model);
      final completer = Completer<String?>();

      String? fullResponse;
      stream.listen(
        (data) {
          fullResponse = (fullResponse ?? '') + (data['content']?.toString() ?? data['delta']?.toString() ?? '');
        },
        onDone: () {
          completer.complete(fullResponse);
        },
        onError: (Object e) {
          completer.completeError(e);
        },
      );

      return completer.future.timeout(const Duration(seconds: 60));
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  StreamingService? getStreamingService() => null;

  Future<void> fetchProviderConfig() async {
    // Stub — fetches provider configuration from gateway
    _log.info('Fetching provider config (stub)');
  }

  Future<bool> setActiveProvider(String model) async {
    _selectedModel = model;
    notifyListeners();
    return true;
  }

  void setPreferredConnectionType(ConnectionType type) {
    switch (type) {
      case ConnectionType.hermes:
        switchBackend(BackendType.hermes);
      case ConnectionType.openclaw:
        switchBackend(BackendType.openclaw);
      case ConnectionType.local:
        // local maps to openclaw for now
        switchBackend(BackendType.openclaw);
    }
  }

  Future<List<dynamic>> getSessionsList() async {
    // Stub — returns empty list until gateway session API is wired
    return [];
  }

  @override
  void dispose() {
    _messageStreamController.close();
    close();
    super.dispose();
  }
}
