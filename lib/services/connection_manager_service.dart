import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'tunnel_service.dart';
import 'streaming_service.dart';
import 'cloud_streaming_service.dart';
import 'auth_service.dart';
import 'settings_preference_service.dart';
import '../models/llm_communication_error.dart';
import '../models/openclaw_provider.dart';
import '../utils/logger.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;

enum ConnectionType { none, local, cloud }

enum GatewayHealthStatus { unknown, healthy, unhealthy, connecting, error }

/// Connection Manager Service - manages connections to LLM providers
/// Standardized on OpenClaw Gateway as the sole provider.
class ConnectionManagerService extends ChangeNotifier {
  final TunnelService _tunnelService;
  final AuthService _authService;
  final SettingsPreferenceService _settings;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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
  String? _gatewayPassword;
  static const String _gatewayPasswordKey = 'openclaw_gateway_password';

  String? get gatewayPassword => _gatewayPassword;

  String? _configuredGatewayUrl;

  ConnectionManagerService({
    required TunnelService tunnelService,
    required AuthService authService,
    required SettingsPreferenceService settings,
  })  : _tunnelService = tunnelService,
        _authService = authService,
        _settings = settings {
    _tunnelService.addListener(_onConnectionChanged);
    _authService.addListener(_onAuthChanged);
    _loadGatewayUrl();
  }

  /// Load configured gateway URL from settings
  Future<void> _loadGatewayUrl() async {
    final url = await _settings.getGatewayUrl();
    if (url?.isNotEmpty ?? false) {
      _configuredGatewayUrl = url;
      appLogger.info('[ConnectionManager] Using configured gateway URL: $_configuredGatewayUrl');
    }
  }

  /// Reload gateway URL from settings and reset connection
  Future<void> reloadGatewayUrl() async {
    await _loadGatewayUrl();
    // Reset streaming service to use new URL on next connection
    _cloudStreamingService = null;
    appLogger.info('[ConnectionManager] Gateway URL reloaded: $_configuredGatewayUrl');
    notifyListeners();
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

  /// Set the OpenClaw Gateway password/token
  Future<void> setGatewayPassword(String? password) async {
    _gatewayPassword = password;
    if (password != null && password.isNotEmpty) {
      await _secureStorage.write(key: _gatewayPasswordKey, value: password);
      debugPrint(
          '[ConnectionManager] Saved gateway password to secure storage');
    } else {
      await _secureStorage.delete(key: _gatewayPasswordKey);
      debugPrint(
          '[ConnectionManager] Removed gateway password from secure storage');
    }
    notifyListeners();
  }

  /// Load gateway password from secure storage or auto-detect from OpenClaw
  Future<void> loadGatewayPassword() async {
    // Try auto-detect first
    final detectedToken = await _autoDetectGatewayToken();
    if (detectedToken != null && detectedToken.isNotEmpty) {
      _gatewayPassword = detectedToken;
      await _secureStorage.write(
          key: _gatewayPasswordKey, value: detectedToken);
      debugPrint('[ConnectionManager] Auto-detected gateway token');
      return;
    }

    // Fall back to secure storage
    try {
      final password = await _secureStorage.read(key: _gatewayPasswordKey);
      if (password != null && password.isNotEmpty) {
        _gatewayPassword = password;
        debugPrint(
            '[ConnectionManager] Loaded gateway password from secure storage');
      }
    } catch (e) {
      debugPrint('[ConnectionManager] Failed to load gateway password: $e');
    }
  }

  /// Auto-detect gateway token from OpenClaw config files
  Future<String?> _autoDetectGatewayToken() async {
    try {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home == null) return null;

      final configPaths = [
        '$home/.config/openclaw/config.yaml',
        '$home/.openclaw/config.yaml',
        '$home/.config/openclaw-gateway/config.yaml',
      ];

      for (final configPath in configPaths) {
        try {
          final file = File(configPath);
          if (await file.exists()) {
            final content = await file.readAsString();
            final lines = content.split('\n');
            for (final line in lines) {
              if (line.contains('gateway.auth.token:') ||
                  line.contains('gateway.remote.token:')) {
                final parts = line.split(':');
                if (parts.length >= 2) {
                  var token = parts.sublist(1).join(':').trim();
                  token = token.replaceAll('"', '').replaceAll("'", '');
                  if (token.isNotEmpty) {
                    debugPrint(
                        '[ConnectionManager] Found token in $configPath');
                    return token;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[ConnectionManager] Could not read $configPath: $e');
        }
      }
    } catch (e) {
      debugPrint('[ConnectionManager] Auto-detect failed: $e');
    }
    return null;
  }

  ConnectionType getBestConnectionType() {
    return ConnectionType.local; // Always prefer local OpenClaw Gateway
  }

  StreamingService? getStreamingService() {
    final connectionType = getBestConnectionType();
    switch (connectionType) {
      case ConnectionType.local:
        final gatewayUrl = _configuredGatewayUrl ?? AppConfig.defaultGatewayUrl;
        _cloudStreamingService ??= CloudStreamingService(
          baseUrl: gatewayUrl,
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
          throw TimeoutException(
              'WebSocket connection timed out after 10 seconds');
        },
      );

      // Send handshake request
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
            'id': 'cli',
            'version': '10.1.187',
            'platform': 'linux',
            'mode': 'cli'
          },
          'role': 'operator',
          'scopes': ['operator.read', 'operator.write'],
          'auth': {'token': token},
          'locale': 'en-US',
          'userAgent': 'CloudToLocalLLM/10.1.187',
        }
      };

      _wsChannel?.sink.add(jsonEncode(connectRequest));

      // Set up stream listener with handshake completion tracking
      final completer = Completer<void>();
      bool handshakeReceived = false;

      _wsChannel!.stream.listen(
        (data) {
          if (!handshakeReceived) {
            // Handle handshake response
            try {
              final msg = jsonDecode(data as String);
              if (msg['type'] == 'res' && msg['id'] == id) {
                if (msg['payload']?['type'] == 'hello-ok') {
                  debugPrint('[ConnectionManager] ✓ Handshake successful');
                  handshakeReceived = true;
                  _isConnected = true;
                  _healthStatus = GatewayHealthStatus.healthy;
                  _lastSuccessfulConnection = DateTime.now();
                  _lastError = null;
                  notifyListeners();
                  completer.complete();
                } else if (msg['ok'] == false) {
                  final error = msg['error']?['message'] ?? 'Handshake failed';
                  completer
                      .completeError(Exception('Handshake rejected: $error'));
                }
              }
            } catch (e) {
              debugPrint('[ConnectionManager] Handshake parse error: $e');
            }
          } else {
            // Handle normal messages after handshake
            _handleWebSocketMessage(data.toString());
          }
        },
        onError: (e) {
          final error = 'WebSocket error: $e';
          debugPrint('[ConnectionManager] $error');
          appLogger.error('[ConnectionManager] WebSocket error', error: e);
          _isConnected = false;
          _healthStatus = GatewayHealthStatus.error;
          _lastError = error;
          notifyListeners();
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        onDone: () {
          debugPrint('[ConnectionManager] WebSocket closed');
          _isConnected = false;
          _healthStatus = GatewayHealthStatus.unhealthy;
          notifyListeners();
          if (!completer.isCompleted) {
            completer
                .completeError(Exception('WebSocket closed during handshake'));
          }
        },
      );

      // Wait for handshake to complete with timeout
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Handshake timed out after 10 seconds'),
      );

      debugPrint(
          '[ConnectionManager] ✓ WebSocket connected to OpenClaw Gateway');
      notifyListeners();
    } catch (e, stack) {
      final error = 'WebSocket connection failed: $e';
      debugPrint('[ConnectionManager] ✗ $error');
      debugPrint('[ConnectionManager] Stack trace: $stack');
      appLogger.error('[ConnectionManager] Connection failed',
          error: e, stackTrace: stack);
      _isConnected = false;
      _healthStatus = GatewayHealthStatus.error;
      _lastError = error;
      notifyListeners();
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
          completer.completeError(
              Exception(msg['error']?['message'] ?? 'Unknown error'));
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
        final completer =
            reqId != null ? _responseCompleters.remove(reqId) : null;
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
        final completer =
            reqId != null ? _responseCompleters.remove(reqId) : null;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
              Exception(payload?['errorMessage'] ?? 'Chat error'));
        }
      }
    }
  }

  Future<void> initialize() async {
    await loadGatewayPassword();
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
        debugPrint(
            '[ConnectionManager] ✓ OpenClaw WebSocket verified and ready');
      } else {
        _availableModels = [];
        debugPrint('[ConnectionManager] ✗ WebSocket connection failed');
      }
    } catch (e, stack) {
      debugPrint('[ConnectionManager] ✗ Connection test exception: $e');
      appLogger.error('[ConnectionManager] Connection test failed',
          error: e, stackTrace: stack);
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
      final timeSinceLastConnection =
          DateTime.now().difference(_lastSuccessfulConnection!);
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
        unawaited(_tunnelService.connect().catchError((e) {
          debugPrint(
              '[ConnectionManager] Tunnel connection failed on auth change: $e');
        }));
      }
    }
    notifyListeners();
  }

  // ========================================================================
  // OpenClaw Provider Management
  // ========================================================================

  OpenClawProviderConfig? _providerConfig;
  List<OpenClawProvider> _availableProviders = [];
  String? _activeProviderModelId;

  /// Get available cloud providers from OpenClaw Gateway
  List<OpenClawProvider> get availableProviders => _availableProviders;

  /// Get current active provider/model ID (format: provider-name/model-id)
  String? get activeProviderModelId => _activeProviderModelId;

  /// Get provider configuration
  OpenClawProviderConfig? get providerConfig => _providerConfig;

  /// Fetch provider configuration from OpenClaw Gateway
  /// Returns true if successful
  Future<bool> fetchProviderConfig() async {
    try {
      final gatewayUrl = _configuredGatewayUrl ?? AppConfig.defaultGatewayUrl;
      final configUrl = '$gatewayUrl/api/v1/config';

      debugPrint('[ConnectionManager] Fetching provider config from $configUrl');

      final response = await http.get(
        Uri.parse(configUrl),
        headers: {
          'Accept': 'application/json',
          if (_gatewayPassword != null && _gatewayPassword!.isNotEmpty)
            'Authorization': 'Bearer $_gatewayPassword',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        _providerConfig = OpenClawProviderConfig.fromJson(jsonData);
        _availableProviders = _providerConfig!.providers.values.toList();
        _activeProviderModelId = _providerConfig!.primaryProvider;

        // Update available models list for backward compatibility
        _updateAvailableModelsList();

        debugPrint('[ConnectionManager] Loaded ${_availableProviders.length} providers');
        debugPrint('[ConnectionManager] Active provider: $_activeProviderModelId');

        notifyListeners();
        return true;
      } else {
        debugPrint('[ConnectionManager] Failed to fetch config: ${response.statusCode}');
        unawaited(_loadConfigFromFile());
        return false;
      }
    } catch (e) {
      debugPrint('[ConnectionManager] Error fetching provider config: $e');
      // Fallback to reading config file directly
      return await _loadConfigFromFile();
    }
  }

  /// Load OpenClaw config from file (fallback method)
  Future<bool> _loadConfigFromFile() async {
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) return false;

      final configFile = File('$homeDir/.openclaw/openclaw.json');
      if (!await configFile.exists()) {
        debugPrint('[ConnectionManager] OpenClaw config file not found');
        return false;
      }

      final configJson = jsonDecode(await configFile.readAsString());
      _providerConfig = OpenClawProviderConfig.fromJson(configJson);
      _availableProviders = _providerConfig!.providers.values.toList();
      _activeProviderModelId = _providerConfig!.primaryProvider;

      _updateAvailableModelsList();

      debugPrint('[ConnectionManager] Loaded config from file: ${_availableProviders.length} providers');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ConnectionManager] Error loading config from file: $e');
      return false;
    }
  }

  /// Update the legacy availableModels list from provider config
  void _updateAvailableModelsList() {
    _availableModels = [];
    for (final provider in _availableProviders) {
      for (final model in provider.models) {
        _availableModels.add(model.fullModelId);
      }
    }
  }

  /// Set the active provider/model in OpenClaw Gateway
  /// Format: "provider-name/model-id" (e.g., "zhipu/glm-4-plus")
  Future<bool> setActiveProvider(String providerModelId) async {
    try {
      final gatewayUrl = _configuredGatewayUrl ?? AppConfig.defaultGatewayUrl;
      final providerUrl = '$gatewayUrl/api/v1/provider';

      debugPrint('[ConnectionManager] Setting provider to: $providerModelId');

      final response = await http.post(
        Uri.parse(providerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (_gatewayPassword != null && _gatewayPassword!.isNotEmpty)
            'Authorization': 'Bearer $_gatewayPassword',
        },
        body: jsonEncode({'provider': providerModelId}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 202) {
        _activeProviderModelId = providerModelId;
        _selectedModel = providerModelId;

        debugPrint('[ConnectionManager] ✓ Provider changed to: $providerModelId');
        notifyListeners();
        return true;
      } else {
        debugPrint('[ConnectionManager] ✗ Failed to set provider: ${response.statusCode}');
        debugPrint('[ConnectionManager] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[ConnectionManager] Error setting provider: $e');
      return false;
    }
  }

  /// Get the active provider object
  OpenClawProvider? get activeProvider {
    if (_activeProviderModelId == null || _providerConfig == null) {
      return null;
    }
    return _providerConfig!.activeProvider;
  }

  /// Get the active model object
  OpenClawModel? get activeModel {
    if (_activeProviderModelId == null || _providerConfig == null) {
      return null;
    }
    return _providerConfig!.activeModel;
  }

  /// Get provider by ID
  OpenClawProvider? getProvider(String providerId) {
    return _providerConfig?.providers[providerId];
  }

  /// Get model by full model ID (provider-name/model-id)
  OpenClawModel? getModel(String fullModelId) {
    final parts = fullModelId.split('/');
    if (parts.length != 2) return null;

    final provider = getProvider(parts[0]);
    return provider?.getModel(parts[1]);
  }

  @override
  void dispose() {
    _tunnelService.removeListener(_onConnectionChanged);
    _authService.removeListener(_onAuthChanged);
    _cloudStreamingService?.dispose();
    super.dispose();
  }
}
