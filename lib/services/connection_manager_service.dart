import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'agent_runtime/agent_runtime_client.dart';
import 'agent_runtime/hermes_runtime_client.dart';
import 'cloud_streaming_service.dart';
import 'hermes_manager/hermes_gateway_control_service.dart';
import 'openclaw_manager/gateway_control_service.dart';
import 'settings_preference_service.dart' as preferences;
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

/// Manages the selected agent runtime session.
///
/// Local model providers are not managed here; they are support providers used
/// by memory/background services only.
/// Extends [ChangeNotifier] so UI layers can reactively observe state.
class ConnectionManagerService extends ChangeNotifier {
  /// The current runtime type, if setup has selected one.
  BackendType? get currentBackend => _currentBackend;
  BackendType? _currentBackend;

  /// The OpenClaw gateway control service.
  final GatewayControlService openclawGatewayService;

  /// The Hermes gateway control service.
  final HermesGatewayControlService hermesGatewayService;

  /// The OpenClaw streaming service (for WebSocket connections).
  CloudStreamingService? _openclawStreamingService;

  /// The active runtime client. Hermes is the first fully wired runtime.
  AgentRuntimeClient? _activeRuntimeClient;
  AgentRuntimeClient? get activeRuntimeClient => _activeRuntimeClient;
  RuntimeCapabilityManifest? get activeRuntimeCapabilities =>
      _activeRuntimeClient?.capabilityManifest;

  final preferences.SettingsPreferenceService? _settingsPreferenceService;
  String? _configuredHermesUrl;
  String? _configuredHermesApiKey;

  // ---------------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------------
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool get hasCloudConnection =>
      _isConnected &&
      _currentBackend != null &&
      _currentBackend != BackendType.hermes;

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
        (_selectedModel == null ||
            !_availableModels.contains(_selectedModel))) {
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

  String? get healthStatus => _isConnected ? 'healthy' : 'disconnected';

  // ---------------------------------------------------------------------------
  // Connection type / backend info
  // ---------------------------------------------------------------------------
  String? get preferredConnectionType => switch (_currentBackend) {
        BackendType.hermes => 'hermes',
        BackendType.openclaw => 'openclaw',
        null => null,
      };

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
    preferences.SettingsPreferenceService? settingsPreferenceService,
  }) : _settingsPreferenceService = settingsPreferenceService;

  // ---------------------------------------------------------------------------
  // Existing API: connect
  // ---------------------------------------------------------------------------
  Stream<Map<String, dynamic>> connect({
    String? hermesUrl,
    String? hermesApiKey,
    String? model,
  }) {
    if (hermesUrl != null && hermesUrl.trim().isNotEmpty) {
      _configuredHermesUrl = hermesUrl.trim();
    }
    if (hermesApiKey != null) {
      _configuredHermesApiKey =
          hermesApiKey.trim().isEmpty ? null : hermesApiKey.trim();
    }

    switch (_currentBackend) {
      case null:
        _lastError = 'No agent runtime selected';
        _isConnected = false;
        notifyListeners();
        _messageStreamController.addError(StateError(_lastError!));
        return _messageStreamController.stream;
      case BackendType.openclaw:
        return _connectToOpenClaw();
      case BackendType.hermes:
        unawaited(_connectToActiveRuntime());
        return _messageStreamController.stream;
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

  // ---------------------------------------------------------------------------
  // Existing API: switchBackend / getBackend / close / initialize
  // ---------------------------------------------------------------------------
  void switchBackend(BackendType newBackend) {
    _log.info('Switching backend from $_currentBackend to $newBackend');
    close();
    _currentBackend = newBackend;
    if (newBackend == BackendType.hermes) {
      _activeRuntimeClient = _createHermesRuntimeClient();
    } else {
      _activeRuntimeClient = null;
    }
    _persistActiveBackend(newBackend);
    notifyListeners();
  }

  void clearActiveRuntime() {
    _log.info('Clearing active runtime selection');
    close();
    _currentBackend = null;
    _activeRuntimeClient = null;
    _persistActiveBackend(null);
    notifyListeners();
  }

  BackendType? getBackend() => _currentBackend;

  void close() {
    final runtimeClient = _activeRuntimeClient;
    if (runtimeClient != null) {
      unawaited(runtimeClient.disconnect());
    }
    _openclawStreamingService?.closeConnection();
    _activeWsChannel = null;
    _isConnected = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    _log.info('Initializing ConnectionManagerService');
    await _loadConfiguredRuntime();
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
      switch (_currentBackend) {
        case null:
          _lastError = 'No agent runtime selected';
          _isConnected = false;
          notifyListeners();
          return false;
        case BackendType.hermes:
          final client = _ensureHermesRuntimeClient();
          final health = await client.health();
          _isConnected = health.isHealthy;
          if (_isConnected) {
            final models = await client.getAvailableModels();
            if (models.isNotEmpty) {
              setAvailableModels(models);
            }
          }
          _lastError = health.isHealthy ? null : health.message;
          notifyListeners();
          return health.isHealthy;
        case BackendType.openclaw:
          await openclawGatewayService.checkStatus();
          break;
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
    final activeBackend = _currentBackend;
    final openclawStatus = openclawGatewayService.state;
    final hermesStatus = hermesGatewayService.getStatus();

    if (activeBackend == null) {
      return {
        'state': 'unconfigured',
        'isRunning': false,
        'isConnected': false,
        'backend': null,
        'backendLabel': 'No agent runtime selected',
        'openclaw': {
          'state': openclawStatus.name,
          'isRunning': openclawStatus == GatewayState.running,
        },
        'hermes': hermesStatus,
      };
    }

    final activeBackendLabel = activeBackend == BackendType.hermes
        ? 'Hermes Agent'
        : 'OpenClaw Gateway';
    final activeStatus = activeBackend == BackendType.hermes
        ? {
            'state': _isConnected ? 'connected' : 'disconnected',
            'running': _isConnected,
          }
        : {
            'state': openclawStatus.name,
            'running': openclawStatus == GatewayState.running,
          };

    return {
      'state': activeStatus['state']?.toString() ?? 'unknown',
      'isRunning': activeBackend == BackendType.hermes
          ? activeStatus['running'] == true
          : openclawStatus == GatewayState.running,
      'isConnected': _isConnected,
      'backend': activeBackend.name,
      'backendLabel': activeBackendLabel,
      'openclaw': {
        'state': openclawStatus.name,
        'isRunning': openclawStatus == GatewayState.running,
      },
      'hermes': hermesStatus,
    };
  }

  bool isGatewayHealthy() {
    return switch (_currentBackend) {
      null => false,
      BackendType.openclaw => _isConnected && openclawGatewayService.isRunning,
      BackendType.hermes => _isConnected,
    };
  }

  Future<bool> startActiveGateway() {
    return switch (_currentBackend) {
      null => Future<bool>.value(false),
      BackendType.openclaw => openclawGatewayService.start(),
      BackendType.hermes => hermesGatewayService.start(),
    };
  }

  Future<bool> stopActiveGateway() {
    return switch (_currentBackend) {
      null => Future<bool>.value(false),
      BackendType.openclaw => openclawGatewayService.stop(),
      BackendType.hermes => hermesGatewayService.stop(),
    };
  }

  Future<bool> restartActiveGateway() {
    return switch (_currentBackend) {
      null => Future<bool>.value(false),
      BackendType.openclaw => openclawGatewayService.restart(),
      BackendType.hermes => hermesGatewayService.restart(),
    };
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
      if (_currentBackend == BackendType.hermes) {
        final client = _ensureHermesRuntimeClient();
        final typedHistory = history
            ?.map(
              (entry) => entry.map(
                (key, value) => MapEntry(key, value?.toString() ?? ''),
              ),
            )
            .toList(growable: false);
        return await client.sendChatMessage(
          model: model,
          prompt: message,
          history: typedHistory,
        );
      }

      final stream = connect(model: model);
      final completer = Completer<String?>();

      String? fullResponse;
      stream.listen(
        (data) {
          fullResponse = (fullResponse ?? '') +
              (data['content']?.toString() ?? data['delta']?.toString() ?? '');
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

  StreamingService? getStreamingService() {
    return switch (_currentBackend) {
      BackendType.hermes => _ensureHermesRuntimeClient().streamingService,
      BackendType.openclaw => null,
      null => null,
    };
  }

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
        clearActiveRuntime();
    }
  }

  void configureHermesRuntime({
    required String url,
    String? apiKey,
  }) {
    _configuredHermesUrl = url.trim().isEmpty ? null : url.trim();
    _configuredHermesApiKey =
        apiKey == null || apiKey.trim().isEmpty ? null : apiKey.trim();
    if (_currentBackend == BackendType.hermes) {
      _activeRuntimeClient = _createHermesRuntimeClient();
      notifyListeners();
    }
  }

  Future<void> _connectToActiveRuntime() async {
    try {
      final client = _activeRuntimeClient;
      if (client == null) {
        _lastError = 'No agent runtime selected';
        _isConnected = false;
        notifyListeners();
        return;
      }

      await client.connect();
      _isConnected = client.connectionState == RuntimeConnectionState.connected;
      _lastSuccessfulConnection = _isConnected ? DateTime.now() : null;
      _lastError = _isConnected ? null : 'Runtime is not healthy';
      final models = client.capabilityManifest.models;
      if (models.isNotEmpty) {
        setAvailableModels(models);
      }
      notifyListeners();
    } catch (e, st) {
      _log.severe('Failed to connect to runtime', e, st);
      _isConnected = false;
      _lastError = e.toString();
      notifyListeners();
    }
  }

  HermesRuntimeClient _ensureHermesRuntimeClient() {
    final existing = _activeRuntimeClient;
    if (existing is HermesRuntimeClient) {
      return existing;
    }

    final client = _createHermesRuntimeClient();
    _activeRuntimeClient = client;
    return client;
  }

  HermesRuntimeClient _createHermesRuntimeClient() {
    return HermesRuntimeClient(
      baseUrl: _configuredHermesUrl ?? 'http://127.0.0.1:8642',
      apiKey: _configuredHermesApiKey,
    );
  }

  Future<void> _loadConfiguredRuntime() async {
    final settings = _settingsPreferenceService;
    if (settings == null) {
      return;
    }

    final configuredBackend = await settings.getActiveBackend();
    _configuredHermesUrl = await settings.getHermesUrl();
    _configuredHermesApiKey = await settings.getHermesApiKey();
    final hermesEnabled = await settings.isHermesEnabled();

    if (configuredBackend == preferences.BackendType.hermes || hermesEnabled) {
      _currentBackend = BackendType.hermes;
      _activeRuntimeClient = _createHermesRuntimeClient();
    } else if (configuredBackend == preferences.BackendType.openclaw) {
      _currentBackend = BackendType.openclaw;
      _activeRuntimeClient = null;
    } else {
      _currentBackend = null;
      _activeRuntimeClient = null;
    }
  }

  void _persistActiveBackend(BackendType? backend) {
    final settings = _settingsPreferenceService;
    if (settings == null) {
      return;
    }

    final preferences.BackendType? preferenceBackend = switch (backend) {
      BackendType.hermes => preferences.BackendType.hermes,
      BackendType.openclaw => preferences.BackendType.openclaw,
      null => null,
    };
    unawaited(settings.setActiveBackend(preferenceBackend));
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
