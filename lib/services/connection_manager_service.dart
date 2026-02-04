import 'dart:async';
import 'package:flutter/foundation.dart';
import 'local_ollama_connection_service.dart';
import 'tunnel_service.dart';
import 'streaming_service.dart';
import 'ollama_service.dart';
import 'cloud_streaming_service.dart';
import 'auth_service.dart';
import '../models/llm_communication_error.dart';
import '../utils/logger.dart';

enum ConnectionType { none, local, cloud }

class ConnectionManagerService extends ChangeNotifier {
  final LocalOllamaConnectionService _localOllama;
  final TunnelService _tunnelService;
  final AuthService _authService;
  final OllamaService _ollamaService;

  bool _preferLocalOllama = true;
  String? _selectedModel;
  CloudStreamingService? _cloudStreamingService;

  ConnectionManagerService({
    required LocalOllamaConnectionService localOllama,
    required TunnelService tunnelService,
    required AuthService authService,
    required OllamaService ollamaService,
  })  : _localOllama = localOllama,
        _tunnelService = tunnelService,
        _authService = authService,
        _ollamaService = ollamaService {
    _localOllama.addListener(_onConnectionChanged);
    _tunnelService.addListener(_onConnectionChanged);
    _authService.addListener(_onAuthChanged);
    _ollamaService.addListener(_onConnectionChanged);
  }

  bool get hasLocalConnection => _localOllama.isConnected;
  bool get hasCloudConnection =>
      kIsWeb ? _ollamaService.isConnected : _tunnelService.isConnected;
  bool get hasAnyConnection => hasLocalConnection || hasCloudConnection;
  String? get selectedModel => _selectedModel;
  List<String> get availableModels => _getAvailableModels();

  ConnectionType getBestConnectionType() {
    if (kIsWeb) {
      return hasCloudConnection ? ConnectionType.cloud : ConnectionType.none;
    }
    if (_preferLocalOllama && hasLocalConnection) {
      return ConnectionType.local;
    }
    if (hasCloudConnection) {
      return ConnectionType.cloud;
    }
    if (hasLocalConnection) {
      return ConnectionType.local;
    }
    return ConnectionType.none;
  }

  StreamingService? getStreamingService() {
    final connectionType = getBestConnectionType();
    switch (connectionType) {
      case ConnectionType.local:
        return _localOllama.streamingService;
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
    final connectionType = getBestConnectionType();
    switch (connectionType) {
      case ConnectionType.local:
        return await _localOllama.chat(
          model: model,
          message: message,
          history: history,
        );
      case ConnectionType.cloud:
        return await _ollamaService.chat(
          model: model,
          message: message,
          history: history,
        );
      default:
        throw LLMCommunicationError.providerNotFound();
    }
  }

  Future<void> initialize() async {
    if (!kIsWeb) {
      try {
        await _localOllama.initialize().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[ConnectionManager] Local Ollama initialization timed out/failed: $e');
      }
    }
    if (_authService.isAuthenticated.value) {
      if (kIsWeb) {
        // On web, we just need to verify the cloud connection
        _ollamaService.testConnection().catchError((e) {
          debugPrint('[ConnectionManager] Cloud connection test failed: $e');
        });
      } else {
        // Desktop: attempt tunnel connection, but don't block initialization
        _tunnelService.connect().catchError((e) {
          debugPrint('[ConnectionManager] Tunnel connection failed during initialization: $e');
        });
      }
    }
    _autoSelectModel();
    notifyListeners();
  }

  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  void setPreferLocalOllama(bool prefer) {
    _preferLocalOllama = prefer;
    notifyListeners();
  }

  Future<void> reconnectAll() async {
    if (!kIsWeb) {
      await _localOllama.reconnect();
    }
    if (!kIsWeb && !_tunnelService.isConnected) {
      try {
        await _tunnelService.connect();
      } catch (e) {
        debugPrint('[ConnectionManager] Tunnel reconnection failed: $e');
        // Continue without tunnel - direct API calls will still work
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> getConnectionStatus() {
    return {
      'local': {'connected': hasLocalConnection, 'models': _localOllama.models},
      'cloud': {'connected': hasCloudConnection},
      'active': getBestConnectionType().name,
      'selectedModel': _selectedModel,
    };
  }

  List<String> _getAvailableModels() {
    final models = <String>{};
    if (hasLocalConnection) {
      models.addAll(_localOllama.models);
    }
    return models.toList()..sort();
  }

  void _autoSelectModel() {
    if (_selectedModel != null) return;
    final models = availableModels;
    if (models.isNotEmpty) {
      setSelectedModel(models.first);
    }
  }

  void _onConnectionChanged() {
    _autoSelectModel();
    notifyListeners();
  }

  void _onAuthChanged() {
    if (_authService.isAuthenticated.value) {
      if (kIsWeb) {
        _ollamaService.testConnection();
      } else if (!_tunnelService.isConnected) {
        // Try to connect tunnel, but don't block on failure
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
    _localOllama.removeListener(_onConnectionChanged);
    _tunnelService.removeListener(_onConnectionChanged);
    _authService.removeListener(_onAuthChanged);
    _ollamaService.removeListener(_onConnectionChanged);
    _cloudStreamingService?.dispose();
    super.dispose();
  }
}
