import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Enhanced system tray service that communicates with the independent tray daemon
///
/// This service provides:
/// - Communication with the enhanced tray daemon
/// - Connection management through the daemon's broker
/// - Authentication token management
/// - Unified API for all connections (local + cloud)
class EnhancedTrayService {
  static final EnhancedTrayService _instance = EnhancedTrayService._internal();
  factory EnhancedTrayService() => _instance;
  EnhancedTrayService._internal();

  Process? _daemonProcess;
  Socket? _socket;
  int? _daemonPort;
  bool _isConnected = false;
  bool _isInitialized = false;
  int _restartAttempts = 0;
  static const int _maxRestartAttempts = 3;
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _healthCheckInterval = Duration(seconds: 30);

  Timer? _healthCheckTimer;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Callbacks for tray events
  VoidCallback? _onShowWindow;
  VoidCallback? _onHideWindow;
  VoidCallback? _onSettings;
  VoidCallback? _onQuit;
  VoidCallback? _onDaemonSettings;
  VoidCallback? _onConnectionStatus;
  VoidCallback? _onOllamaTest;

  /// Stream of messages from the tray daemon
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Initialize the enhanced tray service
  Future<bool> initialize({
    VoidCallback? onShowWindow,
    VoidCallback? onHideWindow,
    VoidCallback? onSettings,
    VoidCallback? onQuit,
    VoidCallback? onDaemonSettings,
    VoidCallback? onConnectionStatus,
    VoidCallback? onOllamaTest,
  }) async {
    if (_isInitialized) return _isConnected;

    _onShowWindow = onShowWindow;
    _onHideWindow = onHideWindow;
    _onSettings = onSettings;
    _onQuit = onQuit;
    _onDaemonSettings = onDaemonSettings;
    _onConnectionStatus = onConnectionStatus;
    _onOllamaTest = onOllamaTest;

    debugPrint("Initializing enhanced tray service...");

    try {
      // Try to connect to existing daemon first with timeout
      final connectResult = await _connectToExistingDaemon()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      if (connectResult) {
        _isInitialized = true;
        _startHealthCheck();
        debugPrint("Connected to existing tray daemon");
        return true;
      }

      // Start new daemon if no existing one found with timeout
      final startResult = await _startDaemon()
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (startResult) {
        final connectNewResult = await _connectToDaemon()
            .timeout(const Duration(seconds: 5), onTimeout: () => false);

        if (connectNewResult) {
          _isInitialized = true;
          _startHealthCheck();
          debugPrint("Started and connected to new tray daemon");
          return true;
        }
      }

      debugPrint(
          "Failed to initialize enhanced tray service - continuing without system tray");
      return false;
    } catch (e) {
      debugPrint(
          "Error initializing enhanced tray service: $e - continuing without system tray");
      return false;
    }
  }

  /// Try to connect to an existing daemon
  Future<bool> _connectToExistingDaemon() async {
    _daemonPort = await _readDaemonPort();
    if (_daemonPort == null) return false;

    return await _connectToDaemon();
  }

  /// Start the enhanced tray daemon process
  Future<bool> _startDaemon() async {
    try {
      final daemonPath = _getDaemonExecutablePath();
      if (daemonPath == null) {
        debugPrint("Enhanced tray daemon executable not found");
        return false;
      }

      debugPrint("Starting enhanced tray daemon: $daemonPath");

      // Start the daemon process
      _daemonProcess = await Process.start(
        daemonPath,
        ['--port', '0'], // Auto-assign port
        mode: ProcessStartMode.detached,
      );

      // Give the daemon time to start and write the port file
      await Future.delayed(const Duration(milliseconds: 2000));

      // Read the port from the port file
      _daemonPort = await _readDaemonPort();
      if (_daemonPort == null) {
        debugPrint("Failed to read daemon port");
        await _stopDaemon();
        return false;
      }

      debugPrint("Enhanced tray daemon started on port $_daemonPort");
      return true;
    } catch (e) {
      debugPrint("Failed to start enhanced tray daemon: $e");
      return false;
    }
  }

  /// Get the path to the enhanced tray daemon executable
  String? _getDaemonExecutablePath() {
    if (Platform.isLinux) {
      final possiblePaths = [
        '/usr/bin/cloudtolocalllm-tray',
        '/usr/local/bin/cloudtolocalllm-tray',
        '${Platform.environment['HOME']}/.local/bin/cloudtolocalllm-tray',
        './tray_daemon/enhanced_tray_daemon.py',
        './enhanced_tray_daemon.py',
      ];

      for (final path in possiblePaths) {
        if (File(path).existsSync()) {
          // For Python scripts, return python3 + script path
          if (path.endsWith('.py')) {
            return 'python3';
          }
          return path;
        }
      }
    } else if (Platform.isWindows) {
      final possiblePaths = [
        '${Platform.environment['PROGRAMFILES']}\\CloudToLocalLLM\\cloudtolocalllm-tray.exe',
        '.\\tray_daemon\\enhanced_tray_daemon.exe',
        '.\\enhanced_tray_daemon.exe',
      ];

      for (final path in possiblePaths) {
        if (File(path).existsSync()) {
          return path;
        }
      }
    } else if (Platform.isMacOS) {
      final possiblePaths = [
        '/Applications/CloudToLocalLLM.app/Contents/MacOS/cloudtolocalllm-tray',
        './tray_daemon/enhanced_tray_daemon.py',
        './enhanced_tray_daemon.py',
      ];

      for (final path in possiblePaths) {
        if (File(path).existsSync()) {
          if (path.endsWith('.py')) {
            return 'python3';
          }
          return path;
        }
      }
    }

    return null;
  }

  /// Read the daemon port from the port file
  Future<int?> _readDaemonPort() async {
    try {
      final portFile = _getPortFilePath();
      if (!await portFile.exists()) return null;

      final portStr = await portFile.readAsString();
      return int.tryParse(portStr.trim());
    } catch (e) {
      debugPrint("Failed to read daemon port: $e");
      return null;
    }
  }

  /// Get the port file path
  File _getPortFilePath() {
    final configDir = _getConfigDir();
    return File(path.join(configDir.path, 'tray_port'));
  }

  /// Get the configuration directory
  Directory _getConfigDir() {
    late String configPath;

    if (Platform.isWindows) {
      configPath = path.join(
          Platform.environment['LOCALAPPDATA'] ??
              Platform.environment['USERPROFILE']!,
          'CloudToLocalLLM');
    } else if (Platform.isMacOS) {
      configPath = path.join(Platform.environment['HOME']!, 'Library',
          'Application Support', 'CloudToLocalLLM');
    } else {
      configPath = path.join(Platform.environment['HOME']!, '.cloudtolocalllm');
    }

    final dir = Directory(configPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Connect to the tray daemon via TCP socket
  Future<bool> _connectToDaemon() async {
    if (_daemonPort == null) return false;

    try {
      debugPrint("Connecting to enhanced tray daemon on port $_daemonPort");

      _socket = await Socket.connect('127.0.0.1', _daemonPort!)
          .timeout(_connectionTimeout);

      // Listen for messages from daemon
      _socket!.listen(
        _handleDaemonMessage,
        onError: (error) {
          debugPrint("Socket error: $error");
          _handleConnectionLost();
        },
        onDone: () {
          debugPrint("Socket connection closed");
          _handleConnectionLost();
        },
      );

      _isConnected = true;
      debugPrint("Connected to enhanced tray daemon");
      return true;
    } catch (e) {
      debugPrint("Failed to connect to enhanced tray daemon: $e");
      return false;
    }
  }

  /// Handle messages from the daemon
  void _handleDaemonMessage(List<int> data) {
    try {
      final message = utf8.decode(data);
      final lines = message.split('\n');

      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          final messageData = jsonDecode(line.trim()) as Map<String, dynamic>;
          _processMessage(messageData);
        }
      }
    } catch (e) {
      debugPrint("Failed to process daemon message: $e");
    }
  }

  /// Process a message from the daemon
  void _processMessage(Map<String, dynamic> message) {
    final command = message['command'] as String?;

    debugPrint(
        "🔄 [EnhancedTrayService] Received command from daemon: $command");
    debugPrint("🔄 [EnhancedTrayService] Full message: $message");

    switch (command) {
      case 'SHOW':
        debugPrint("🪟 [EnhancedTrayService] Executing SHOW command");
        if (_onShowWindow != null) {
          _onShowWindow!.call();
          debugPrint("✅ [EnhancedTrayService] SHOW callback executed");
        } else {
          debugPrint("❌ [EnhancedTrayService] SHOW callback is null");
        }
        break;
      case 'HIDE':
        debugPrint("🫥 [EnhancedTrayService] Executing HIDE command");
        if (_onHideWindow != null) {
          _onHideWindow!.call();
          debugPrint("✅ [EnhancedTrayService] HIDE callback executed");
        } else {
          debugPrint("❌ [EnhancedTrayService] HIDE callback is null");
        }
        break;
      case 'SETTINGS':
        debugPrint("⚙️ [EnhancedTrayService] Executing SETTINGS command");
        if (_onSettings != null) {
          _onSettings!.call();
          debugPrint("✅ [EnhancedTrayService] SETTINGS callback executed");
        } else {
          debugPrint("❌ [EnhancedTrayService] SETTINGS callback is null");
        }
        break;
      case 'DAEMON_SETTINGS':
        debugPrint(
            "🔧 [EnhancedTrayService] Executing DAEMON_SETTINGS command");
        if (_onDaemonSettings != null) {
          _onDaemonSettings!.call();
          debugPrint(
              "✅ [EnhancedTrayService] DAEMON_SETTINGS callback executed");
        } else {
          debugPrint(
              "❌ [EnhancedTrayService] DAEMON_SETTINGS callback is null");
        }
        break;
      case 'CONNECTION_STATUS':
        debugPrint(
            "📊 [EnhancedTrayService] Executing CONNECTION_STATUS command");
        if (_onConnectionStatus != null) {
          _onConnectionStatus!.call();
          debugPrint(
              "✅ [EnhancedTrayService] CONNECTION_STATUS callback executed");
        } else {
          debugPrint(
              "❌ [EnhancedTrayService] CONNECTION_STATUS callback is null");
        }
        break;
      case 'OLLAMA_TEST':
        debugPrint("🧪 [EnhancedTrayService] Executing OLLAMA_TEST command");
        if (_onOllamaTest != null) {
          _onOllamaTest!.call();
          debugPrint("✅ [EnhancedTrayService] OLLAMA_TEST callback executed");
        } else {
          debugPrint("❌ [EnhancedTrayService] OLLAMA_TEST callback is null");
        }
        break;
      case 'QUIT':
        debugPrint("🚪 [EnhancedTrayService] Executing QUIT command");
        if (_onQuit != null) {
          _onQuit!.call();
          debugPrint("✅ [EnhancedTrayService] QUIT callback executed");
        } else {
          debugPrint("❌ [EnhancedTrayService] QUIT callback is null");
        }
        break;
      case 'CONNECTION_STATUS_CHANGED':
        debugPrint(
            "📡 [EnhancedTrayService] Broadcasting connection status change");
        // Broadcast connection status changes
        _messageController.add(message);
        break;
      default:
        debugPrint(
            "❓ [EnhancedTrayService] Unknown command from daemon: $command");
    }
  }

  /// Handle connection lost
  void _handleConnectionLost() {
    _isConnected = false;
    _socket = null;

    if (_restartAttempts < _maxRestartAttempts) {
      _restartAttempts++;
      debugPrint(
          "Connection lost, attempting restart ($_restartAttempts/$_maxRestartAttempts)");

      Future.delayed(const Duration(seconds: 2), () async {
        if (await _startDaemon()) {
          await _connectToDaemon();
        }
      });
    } else {
      debugPrint("Max restart attempts reached, giving up");
    }
  }

  /// Start health check timer
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _sendPing();
    });
  }

  /// Send ping to daemon
  void _sendPing() {
    _sendCommand({'command': 'PING'});
  }

  /// Send a command to the daemon
  Future<bool> _sendCommand(Map<String, dynamic> command) async {
    if (_socket == null) return false;

    try {
      final message = '${jsonEncode(command)}\n';
      _socket!.add(utf8.encode(message));
      return true;
    } catch (e) {
      debugPrint("Failed to send command to daemon: $e");
      return false;
    }
  }

  /// Send a command and wait for response
  Future<Map<String, dynamic>?> _sendCommandWithResponse(
      Map<String, dynamic> command,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_socket == null) return null;

    final completer = Completer<Map<String, dynamic>?>();
    late StreamSubscription subscription;

    // Listen for response
    subscription = messageStream.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message);
        subscription.cancel();
      }
    });

    // Set timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
        subscription.cancel();
      }
    });

    // Send command
    if (await _sendCommand(command)) {
      return await completer.future;
    } else {
      subscription.cancel();
      return null;
    }
  }

  /// Update the tray tooltip
  Future<void> setTooltip(String tooltip) async {
    await _sendCommand({
      'command': 'UPDATE_TOOLTIP',
      'text': tooltip,
    });
  }

  /// Update the tray icon state
  Future<void> updateIconState(String state) async {
    await _sendCommand({
      'command': 'UPDATE_ICON',
      'state': state, // idle, connected, error
    });
  }

  /// Update authentication status
  Future<void> updateAuthStatus(bool authenticated) async {
    await _sendCommand({
      'command': 'AUTH_STATUS',
      'authenticated': authenticated,
    });
  }

  /// Update authentication token for cloud connections
  Future<void> updateAuthToken(String token) async {
    await _sendCommand({
      'command': 'UPDATE_AUTH_TOKEN',
      'token': token,
    });
  }

  /// Get connection status from the daemon
  Future<Map<String, dynamic>?> getConnectionStatus() async {
    final response = await _sendCommandWithResponse({
      'command': 'GET_CONNECTION_STATUS',
    });

    return response?['status'] as Map<String, dynamic>?;
  }

  /// Send connection status update to daemon
  Future<bool> updateConnectionStatus(Map<String, dynamic> status) async {
    debugPrint(
        "📡 [EnhancedTrayService] Sending connection status update: $status");
    return await _sendCommand({
      'command': 'UPDATE_CONNECTION_STATUS',
      'status': status,
    });
  }

  /// Send Ollama connection status to daemon
  Future<bool> updateOllamaStatus({
    required bool connected,
    String? version,
    List<String>? models,
    String? error,
  }) async {
    final status = {
      'connected': connected,
      'connection_type': 'ollama',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (version != null) status['version'] = version;
    if (models != null) status['models'] = models;
    if (error != null) status['error'] = error;

    debugPrint(
        "🦙 [EnhancedTrayService] Sending Ollama status update: $status");
    return await updateConnectionStatus(status);
  }

  /// Send cloud connection status to daemon
  Future<bool> updateCloudStatus({
    required bool connected,
    String? endpoint,
    String? error,
  }) async {
    final status = {
      'connected': connected,
      'connection_type': 'cloud',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (endpoint != null) status['endpoint'] = endpoint;
    if (error != null) status['error'] = error;

    debugPrint("☁️ [EnhancedTrayService] Sending cloud status update: $status");
    return await updateConnectionStatus(status);
  }

  /// Proxy a request through the daemon's connection broker
  Future<Map<String, dynamic>?> proxyRequest({
    required String method,
    required String path,
    Map<String, dynamic>? data,
  }) async {
    final response = await _sendCommandWithResponse({
      'command': 'PROXY_REQUEST',
      'method': method,
      'path': path,
      'data': data,
    });

    if (response?['error'] != null) {
      throw Exception(response!['error']);
    }

    return response?['result'] as Map<String, dynamic>?;
  }

  /// Stop the daemon
  Future<void> _stopDaemon() async {
    if (_daemonProcess != null) {
      try {
        _daemonProcess!.kill();
        await _daemonProcess!.exitCode;
      } catch (e) {
        debugPrint("Error stopping daemon process: $e");
      }
      _daemonProcess = null;
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    _healthCheckTimer?.cancel();

    if (_socket != null) {
      try {
        await _sendCommand({'command': 'QUIT'});
        _socket!.close();
      } catch (e) {
        debugPrint("Error closing socket: $e");
      }
      _socket = null;
    }

    await _stopDaemon();
    await _messageController.close();

    _isConnected = false;
    _isInitialized = false;
  }

  /// Check if the service is connected to the daemon
  bool get isConnected => _isConnected;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;
}
