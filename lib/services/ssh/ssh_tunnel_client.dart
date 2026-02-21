import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../models/tunnel_config.dart';
import 'websocket_ssh_socket.dart';

/// SSH tunnel client for establishing reverse proxy connections over WebSocket
///
/// This replaces Chisel with pure Dart SSH-over-WebSocket tunneling.
/// SSH handles secure tunneling, while WebSocket acts as the transport layer
/// to bypass restrictive firewalls.
class SSHTunnelClient with ChangeNotifier {
  final TunnelConfig _config;
  final Dio _dio = Dio();

  SSHClient? _sshClient;
  dynamic _forwarder; // SSH forwarder for reverse tunneling
  bool _isConnected = false;
  int? _tunnelPort;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _tunnelId; // SSH tunnel identifier
  bool _isDisposed = false;

  SSHTunnelClient(this._config);

  bool get isConnected => _isConnected;
  int? get tunnelPort => _tunnelPort;

  /// Connect to SSH server over WebSocket
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_isConnected) {
      debugPrint('[SSH] Already connected');
      return;
    }

    _reconnectAttempts = 0;
    await _doConnect();
  }

  /// Internal connect method
  Future<void> _doConnect() async {
    if (_isDisposed) return;
    if (_isConnected) return;

    try {
      debugPrint('[SSH] Connecting to SSH server over WebSocket...');

      // Convert cloudProxyUrl to WebSocket URL
      final wsUrl = _config.cloudProxyUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      // Add JWT token as query parameter for authentication
      final uri = Uri.parse(wsUrl);
      final wsUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        queryParameters: {
          'token': _config.authToken,
          'userId': _config.userId,
        },
      );

      debugPrint(
          '[SSH] WebSocket URL: ${wsUri.toString().replaceAll(_config.authToken, '[REDACTED]')}');

      if (_isDisposed) return;

      // Connect WebSocket
      final socket = await WebSocketSSHSocket.connect(wsUri);

      if (_isDisposed) {
        await socket.close();
        return;
      }

      // Create SSH client with JWT as password
      _sshClient = SSHClient(
        socket,
        username: _config.userId,
        onPasswordRequest: () => _config.authToken, // Use JWT as password
      );

      debugPrint('[SSH] Authenticating with SSH server...');

      // Authenticate with server
      await _sshClient!.authenticated;

      if (_isDisposed) {
        _sshClient?.close();
        return;
      }

      debugPrint('[SSH] SSH authentication successful');

      // Generate tunnel ID
      _tunnelId ??= 'ssh_tunnel_${DateTime.now().millisecondsSinceEpoch}';

      // Establish reverse port forwarding
      await _establishReverseTunnel();

      // Register with server
      await _registerWithServer();

      _isConnected = true;
      _reconnectAttempts = 0;

      if (!_isDisposed) {
        notifyListeners();
        debugPrint('[SSH] Connection established');
      }
    } catch (e, stackTrace) {
      if (!_isDisposed) {
        debugPrint('[SSH] Connection failed: $e');
        debugPrint('[SSH] Stack trace: $stackTrace');
        _handleDisconnection();
      }
      rethrow;
    }
  }

  /// Register tunnel with server
  Future<void> _registerWithServer() async {
    try {
      final serverUrl = _config.cloudProxyUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://');

      // Better way to get baseUrl: remove trailing path segments but keep port
      final uri = Uri.parse(serverUrl);
      final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

      final registerUrl = Uri.parse('$baseUrl/api/tunnel/register');

      debugPrint('[SSH] Registering with URL: $registerUrl');

      final response = await _dio.post(
        registerUrl.toString(),
        data: {
          'tunnelId': _tunnelId,
          'localPort': _extractLocalPort(_config.localBackendUrl),
          'serverPort': _tunnelPort,
        },
        options: Options(headers: {
          'Authorization': 'Bearer ${_config.authToken}',
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _tunnelPort = data['serverPort'] as int? ?? _tunnelPort;
        debugPrint('[SSH] Registered with server: port $_tunnelPort');
      } else {
        debugPrint(
            '[SSH] Registration failed: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      debugPrint('[SSH] Error registering with server: $e');
      // Don't throw - connection may still work
    }
  }

  /// Establish reverse port forwarding
  Future<void> _establishReverseTunnel() async {
    try {
      debugPrint('[SSH] Establishing reverse port forwarding...');

      // Get local port from config (typically 11434 for Ollama)
      final localPort = _extractLocalPort(_config.localBackendUrl);

      // Request reverse port forwarding from server
      // The server will assign a port and forward connections to our local port
      _forwarder = await _sshClient!.forwardRemote(port: localPort);

      debugPrint('[SSH] Reverse tunnel established for local port $localPort');
    } catch (e) {
      debugPrint('[SSH] Failed to establish reverse tunnel: $e');
      throw Exception('Failed to establish reverse tunnel: $e');
    }
  }

  /// Extract local port from URL
  int _extractLocalPort(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.port != 0 ? uri.port : 11434; // Default Ollama port
    } catch (e) {
      return 11434;
    }
  }

  /// Handle disconnection
  void _handleDisconnection() {
    if (_isDisposed) return;
    if (!_isConnected) return;

    _isConnected = false;
    _tunnelPort = null;
    _tunnelId = null;

    try {
      _forwarder?.close();
      _forwarder = null;
    } catch (e) {
      debugPrint('[SSH] Error closing forwarder: $e');
    }

    try {
      _sshClient?.close();
      _sshClient = null;
    } catch (e) {
      debugPrint('[SSH] Error closing SSH client: $e');
    }

    // Unregister asynchronously
    _unregisterFromServer();

    if (!_isDisposed) {
      notifyListeners();
      debugPrint('[SSH] Disconnected, attempting reconnect...');
      _reconnect();
    }
  }

  /// Reconnect with exponential backoff
  void _reconnect() {
    if (_isDisposed) return;
    if (_reconnectTimer?.isActive ?? false) return;

    final backoffTime = _getReconnectDelay();
    _reconnectAttempts++;

    debugPrint(
        '[SSH] Reconnecting in ${backoffTime.inSeconds} seconds (attempt $_reconnectAttempts)...');

    _reconnectTimer = Timer(backoffTime, () {
      if (!_isDisposed) {
        _doConnect();
      }
    });
  }

  /// Get reconnection delay with exponential backoff
  Duration _getReconnectDelay() {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, then 30s max
    if (_reconnectAttempts >= 5) {
      return const Duration(seconds: 30);
    }
    return Duration(seconds: 1 << _reconnectAttempts);
  }

  /// Unregister from server
  Future<void> _unregisterFromServer() async {
    if (_tunnelId == null) return;

    try {
      final serverUrl = _config.cloudProxyUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://');

      final uri = Uri.parse(serverUrl);
      final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

      await _dio.post(
        '$baseUrl/api/tunnel/unregister',
        options: Options(headers: {
          'Authorization': 'Bearer ${_config.authToken}',
          'Content-Type': 'application/json',
        }),
      );
      debugPrint('[SSH] Unregistered from server');
    } catch (e) {
      debugPrint('[SSH] Error unregistering from server: $e');
    }
  }

  /// Disconnect from SSH server
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _unregisterFromServer();

    try {
      _forwarder?.close();
      _forwarder = null;
    } catch (e) {
      debugPrint('[SSH] Error closing forwarder: $e');
    }

    try {
      _sshClient?.close();
      _sshClient = null;
    } catch (e) {
      debugPrint('[SSH] Error closing SSH client: $e');
    }

    _isConnected = false;
    _tunnelPort = null;
    _tunnelId = null;

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    disconnect();
    super.dispose();
  }
}
