import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'tunnel_service.dart';
import 'streaming_service.dart';
import 'cloud_streaming_service.dart';
import 'auth_service.dart';
import '../models/llm_communication_error.dart';
import '../utils/logger.dart';
import '../config/app_config.dart';

enum ConnectionType { none, local, cloud }

/// Connection Manager Service - manages connections to LLM providers
/// Standardized on OpenClaw Gateway as the sole provider.
class ConnectionManagerService extends ChangeNotifier {
  final TunnelService _tunnelService;
  final AuthService _authService;

  String? _selectedModel;
  CloudStreamingService? _cloudStreamingService;
  bool _isOpenClawAvailable = false;
  List<String> _availableModels = [];

  ConnectionManagerService({
    required TunnelService tunnelService,
    required AuthService authService,
  })  : _tunnelService = tunnelService,
        _authService = authService {
    _tunnelService.addListener(_onConnectionChanged);
    _authService.addListener(_onAuthChanged);
  }

  bool get hasLocalConnection => _isOpenClawAvailable;
  bool get hasCloudConnection => _tunnelService.isConnected;
  bool get hasAnyConnection => hasLocalConnection || hasCloudConnection;
  String? get selectedModel => _selectedModel;
  List<String> get availableModels => _availableModels;

  ConnectionType getBestConnectionType() {
    if (hasLocalConnection) {
      return ConnectionType.local;
    }
    if (hasCloudConnection) {
      return ConnectionType.cloud;
    }
    return ConnectionType.none;
  }

  StreamingService? getStreamingService() {
    final connectionType = getBestConnectionType();
    switch (connectionType) {
      case ConnectionType.local:
        // For local OpenClaw, we use a simple HTTP implementation for now
        // In a full implementation, this would return a specific OpenClawStreamingService
        return null; 
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
    
    if (connectionType == ConnectionType.none) {
      throw LLMCommunicationError.providerNotFound();
    }

    final baseUrl = connectionType == ConnectionType.local 
        ? AppConfig.defaultGatewayUrl 
        : AppConfig.cloudGatewayUrl;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': [
            ...?history,
            {'role': 'user', 'content': message},
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String?;
      } else {
        throw LLMCommunicationError(
          type: LLMCommunicationErrorType.modelError,
          message: 'OpenClaw Gateway returned error: ${response.body}',
          severity: ErrorSeverity.medium,
          recoveryStrategy: RecoveryStrategy.retry,
          httpStatusCode: response.statusCode,
        );
      }
    } catch (e) {
      appLogger.error('[ConnectionManager] Chat request failed: $e');
      rethrow;
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
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.defaultGatewayUrl}/v1/models'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _isOpenClawAvailable = true;
        final data = jsonDecode(response.body);
        _availableModels = (data['data'] as List)
            .map((m) => m['id'] as String)
            .toList();
      } else {
        _isOpenClawAvailable = false;
        _availableModels = [];
      }
    } catch (e) {
      _isOpenClawAvailable = false;
      _availableModels = [];
    }
    notifyListeners();
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
          debugPrint('[ConnectionManager] Tunnel connection failed on auth change: $e');
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
