import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/tunnel_config.dart';
import '../models/tunnel_state.dart';
import '../services/auth_service.dart';
import 'ssh/ssh_tunnel_client.dart'
    if (dart.library.html) 'ssh_tunnel_client_stub.dart';

/// Modern tunnel service with proper state management and error handling
///
/// Responsibilities:
/// - Manage tunnel connection lifecycle
/// - Provide reactive state updates
/// - Handle errors gracefully
/// - Monitor connection health
class TunnelService extends ChangeNotifier {
  final AuthService _authService;
  SSHTunnelClient? _client;
  TunnelState _state = const TunnelState();
  Timer? _healthCheckTimer;
  Timer? _statsTimer;

  TunnelService({required AuthService authService})
      : _authService = authService {
    _initialize();
  }

  TunnelState get state => _state;
  bool get isConnected => _state.isConnected;
  bool get isConnecting => _state.isConnecting;
  String? get error => _state.error;

  void _initialize() {
    // Auto-connect if user is authenticated
    _authService.isAuthenticated.addListener(_onAuthChanged);
    if (_authService.isAuthenticated.value) {
      _autoConnect();
    }
  }

  void _onAuthChanged() {
    if (_authService.isAuthenticated.value) {
      _autoConnect();
    } else {
      disconnect();
    }
  }

  Future<void> _autoConnect() async {
    if (_state.isConnected || _state.isConnecting) return;

    try {
      // Give auth service time to populate currentUser
      await Future.delayed(const Duration(milliseconds: 500));
      await connect();
    } catch (e) {
      // Silently fail auto-connect - user can manually connect
      debugPrint('[TunnelService] Auto-connect failed: $e');
    }
  }

  /// Connect to tunnel
  Future<void> connect() async {
    if (_state.isConnecting || _state.isConnected) return;

    // SSH tunnel client only works on desktop, not web
    if (kIsWeb) {
      // Silently skip on web - tunnel runs on desktop only, web uses cloud proxy
      return;
    }

    _updateState(_state.copyWith(
      isConnecting: true,
      error: null,
    ));

    try {
      if (!_authService.isAuthenticated.value) {
        throw Exception('User not authenticated');
      }

      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('User ID not available');
      }

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        throw Exception('Failed to get access token');
      }

      final config = TunnelConfig(
        userId: userId,
        cloudProxyUrl:
            kDebugMode ? AppConfig.tunnelSshUrl : AppConfig.tunnelSshUrl,
        localBackendUrl: 'http://localhost:11434',
        authToken: token,
        enableCloudProxy: true,
      );

      _client?.dispose();
      _client = SSHTunnelClient(config);
      _client!.addListener(_onClientStateChanged);

      await _client!.connect();

      // Wait a moment for connection to stabilize
      await Future.delayed(const Duration(seconds: 2));

      if (_client!.isConnected) {
        _updateState(_state.copyWith(
          isConnected: true,
          isConnecting: false,
          connectedAt: DateTime.now(),
          tunnelPort: _client!.tunnelPort,
          quality: TunnelConnectionQuality.good,
        ));

        _startHealthMonitoring();
        _startStatsCollection();
      } else {
        throw Exception(
            'Connection established but client reports disconnected');
      }
    } catch (e, stackTrace) {
      debugPrint('[TunnelService] Connection failed: $e');
      debugPrint('[TunnelService] Stack trace: $stackTrace');

      // Check for Windows Defender / antivirus quarantine errors
      String errorMessage = e.toString();
      if (errorMessage.contains('ProcessException') ||
          errorMessage.contains('virus') ||
          errorMessage.contains('quarantine') ||
          errorMessage.contains('Windows Defender')) {
        errorMessage =
            'Connection blocked by security software. Please check antivirus settings.';
      }

      _updateState(_state.copyWith(
        isConnecting: false,
        error: errorMessage,
      ));

      _client?.dispose();
      _client = null;
    }
  }

  /// Disconnect from tunnel
  Future<void> disconnect() async {
    if (_state.isDisconnecting) return;

    _updateState(_state.copyWith(isDisconnecting: true));

    try {
      _stopHealthMonitoring();
      _stopStatsCollection();

      await _client?.disconnect();
      _client?.dispose();
      _client = null;

      _updateState(_state.copyWith(
        isConnected: false,
        isDisconnecting: false,
        connectedAt: null,
        tunnelPort: null,
        tunnelId: null,
      ));
    } catch (e) {
      debugPrint('[TunnelService] Disconnect error: $e');
      _updateState(_state.copyWith(
        isDisconnecting: false,
        error: e.toString(),
      ));
    }
  }

  /// Test tunnel connection
  Future<bool> testConnection() async {
    if (_client == null || !_client!.isConnected) {
      return false;
    }

    try {
      // Real WebSocket connection test
      final testWebSocket = await _createTestWebSocketConnection();
      if (testWebSocket != null) {
        await testWebSocket.close();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[TunnelService] Connection test failed: $e');
      return false;
    }
  }

  /// Create a test WebSocket connection to verify tunnel functionality
  Future<WebSocket?> _createTestWebSocketConnection() async {
    try {
      final config = TunnelConfig(
        userId: _authService.currentUser?.id ?? '',
        cloudProxyUrl:
            kDebugMode ? AppConfig.tunnelSshUrl : AppConfig.tunnelSshUrl,
        localBackendUrl: 'http://localhost:11434',
        authToken: await _authService.getValidatedAccessToken() ?? '',
        enableCloudProxy: true,
      );

      // Create a test WebSocket connection
      final wsUrl = Uri.parse(config.cloudProxyUrl.replaceFirst('http', 'ws'));
      final webSocket = await WebSocket.connect(
        wsUrl.toString(),
        headers: {
          'Authorization': 'Bearer ${config.authToken}',
          'X-Tunnel-Test': 'true',
        },
      );

      // Send a test message and expect a response
      webSocket.add(
          '{"type":"ping","timestamp":"${DateTime.now().toIso8601String()}"}');

      // Wait for response with timeout
      final completer = Completer<bool>();
      webSocket.listen(
        (message) {
          if (message.toString().contains('pong')) {
            completer.complete(true);
          }
        },
        onError: (error) => completer.complete(false),
        onDone: () => completer.complete(false),
      );

      // Timeout after 5 seconds
      final timeout = Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      final success = await completer.future;
      timeout.cancel();

      if (success) {
        return webSocket;
      } else {
        await webSocket.close();
        return null;
      }
    } catch (e) {
      debugPrint('[TunnelService] Failed to create test WebSocket: $e');
      return null;
    }
  }

  void _onClientStateChanged() {
    if (_client == null) return;

    final clientConnected = _client!.isConnected;

    if (clientConnected != _state.isConnected) {
      if (clientConnected) {
        _updateState(_state.copyWith(
          isConnected: true,
          isConnecting: false,
          connectedAt: DateTime.now(),
          tunnelPort: _client!.tunnelPort,
        ));
        _startHealthMonitoring();
        _startStatsCollection();
      } else {
        _updateState(_state.copyWith(
          isConnected: false,
          connectedAt: null,
        ));
        _stopHealthMonitoring();
        _stopStatsCollection();
      }
    }
  }

  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_client == null || !_client!.isConnected) return;

      try {
        final isHealthy = await testConnection();
        if (!isHealthy && _state.isConnected) {
          _updateState(_state.copyWith(
            error: 'Connection health check failed',
            quality: TunnelConnectionQuality.poor,
          ));
        }
      } catch (e) {
        debugPrint('[TunnelService] Health check failed: $e');
      }
    });
  }

  void _stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  void _startStatsCollection() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Update stats based on client metrics
      // This is a placeholder - implement based on actual metrics
    });
  }

  void _stopStatsCollection() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void _updateState(TunnelState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.isAuthenticated.removeListener(_onAuthChanged);
    _stopHealthMonitoring();
    _stopStatsCollection();
    _client?.dispose();
    super.dispose();
  }
}
