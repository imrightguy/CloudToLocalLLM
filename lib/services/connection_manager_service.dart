import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'streaming_service.dart';
import 'openclaw_gateway_service.dart';

enum ConnectionType { none, openclaw, local, cloud }

class ConnectionManagerService extends ChangeNotifier {
  final AuthService _authService;
  final OpenClawGatewayService _gateway;

  String? _selectedModel;

  ConnectionManagerService({
    required AuthService authService,
    required OpenClawGatewayService gateway,
  })  : _authService = authService,
        _gateway = gateway {
    _authService.addListener(notifyListeners);
    _gateway.addListener(notifyListeners);
  }

  bool get isConnected => _gateway.isConnected;
  bool get hasAnyConnection => isConnected;

  // Stubs for compatibility
  bool get hasLocalConnection => false;
  bool get hasCloudConnection => isConnected;
  String? get selectedModel => _selectedModel ?? (_getAvailableModels().isNotEmpty ? _getAvailableModels().first : null);
  List<String> get availableModels => _getAvailableModels();

  ConnectionType getBestConnectionType() {
    return isConnected ? ConnectionType.openclaw : ConnectionType.none;
  }

  StreamingService? getStreamingService() {
    // This will be refactored to use OpenClaw Gateway
    return null;
  }

  Future<String?> sendChatMessage({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    // All chat should go through OpenClaw Gateway
    return "This is a placeholder. All LLM logic is managed by OpenClaw ONLY.";
  }

  Future<void> initialize() async {
    _gateway.connect();
    notifyListeners();
  }

  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  Future<void> reconnectAll() async {
    _gateway.connect();
    notifyListeners();
  }

  Map<String, dynamic> getConnectionStatus() {
    return {
      'connected': isConnected,
      'gateway_state': _gateway.state.toString(),
    };
  }

  List<String> _getAvailableModels() {
    return ['openclaw-default'];
  }

  @override
  void dispose() {
    _authService.removeListener(notifyListeners);
    _gateway.removeListener(notifyListeners);
    super.dispose();
  }
}
