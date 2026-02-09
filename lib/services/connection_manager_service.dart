import 'dart:async';
import 'package:flutter/foundation.dart';
import 'tunnel_service.dart';
import 'streaming_service.dart';
import 'cloud_streaming_service.dart';
import 'auth_service.dart';
import '../models/llm_communication_error.dart';
import '../utils/logger.dart';

enum ConnectionType { none, local, cloud }

/// Connection Manager Service - manages connections to LLM providers
/// Note: Ollama integration removed - use GUI Automation or vLLM directly
class ConnectionManagerService extends ChangeNotifier {
  final TunnelService _tunnelService;
  final AuthService _authService;

  String? _selectedModel;
  CloudStreamingService? _cloudStreamingService;

  ConnectionManagerService({
    required TunnelService tunnelService,
    required AuthService authService,
  })  : _tunnelService = tunnelService,
        _authService = authService {
    _tunnelService.addListener(_onConnectionChanged);
    _authService.addListener(_onAuthChanged);
  }

  bool get hasLocalConnection => false; // Ollama removed
  bool get hasCloudConnection => _tunnelService.isConnected;
  bool get hasAnyConnection => hasLocalConnection || hasCloudConnection;
  String? get selectedModel => _selectedModel;
  List<String> get availableModels => _getAvailableModels();

  ConnectionType getBestConnectionType() {
    if (hasCloudConnection) {
      return ConnectionType.cloud;
    }
    return ConnectionType.none;
  }

  StreamingService? getStreamingService() {
    final connectionType = getBestConnectionType();
    switch (connectionType) {
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
      case ConnectionType.cloud:
        // Cloud streaming only - Ollama removed
        throw LLMCommunicationError.providerNotFound();
      default:
        throw LLMCommunicationError.providerNotFound();
    }
  }

  Future<void> initialize() async {
    if (_authService.isAuthenticated.value) {
      // Desktop: attempt tunnel connection, but don't fail if it doesn't work
      try {
        await _tunnelService.connect();
      } catch (e) {
        debugPrint('[ConnectionManager] Tunnel connection failed: $e');
        // Continue without tunnel - direct API calls will still work
      }
    }
    _autoSelectModel();
    notifyListeners();
  }

  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  Future<void> reconnectAll() async {
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
      'local': {'connected': hasLocalConnection, 'models': <String>[]},
      'cloud': {'connected': hasCloudConnection},
      'active': getBestConnectionType().name,
      'selectedModel': _selectedModel,
    };
  }

  List<String> _getAvailableModels() {
    // Ollama models removed - return empty list
    return <String>[];
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
      if (!kIsWeb && !_tunnelService.isConnected) {
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
    _tunnelService.removeListener(_onConnectionChanged);
    _authService.removeListener(_onAuthChanged);
    _cloudStreamingService?.dispose();
    super.dispose();
  }
}
