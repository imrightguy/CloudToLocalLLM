import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart'
    hide BackendType;
import 'package:cloudtolocalllm/services/connection_manager_service.dart';

enum GatewayState {
  unknown,
  starting,
  running,
  stopping,
  stopped,
  error,
}

class GatewayControlService extends ChangeNotifier {
  GatewayState _state = GatewayState.unknown;
  String? _errorMessage;
  DateTime? _startedAt;
  Timer? _healthCheckTimer;
  final SettingsPreferenceService _settings;
  bool _autoRestartEnabled = true;
  int _restartAttempts = 0;
  bool _isDisposed = false;
  static const int _maxRestartAttempts = 5;
  ConnectionManagerService? _connectionManager;

  GatewayControlService(this._settings, [this._connectionManager]) {
    _loadAutoRestartSetting();

    // Listen to connection changes if connection manager is provided
    if (_connectionManager != null) {
      _connectionManager!.addListener(_onConnectionChanged);
    }
  }

  void setConnectionManager(ConnectionManagerService connectionManager) {
    if (_connectionManager != null) {
      _connectionManager!.removeListener(_onConnectionChanged);
    }
    _connectionManager = connectionManager;
    _connectionManager!.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    // Auto-check status when WebSocket connects
    if (_connectionManager!.currentBackend == BackendType.openclaw &&
        _connectionManager!.isConnected &&
        _connectionManager!.isGatewayHealthy()) {
      debugPrint(
          '[GatewayControl] WebSocket connected, checking gateway status...');
      checkStatus().catchError((e) {
        debugPrint('[GatewayControl] Failed to auto-check status: $e');
      });
    }
  }

  GatewayState get state => _state;
  String? get errorMessage => _errorMessage;
  DateTime? get startedAt => _startedAt;
  bool get isRunning => _state == GatewayState.running;
  bool get isStarting => _state == GatewayState.starting;
  bool get isStopping => _state == GatewayState.stopping;
  bool get autoRestartEnabled => _autoRestartEnabled;

  Future<void> _loadAutoRestartSetting() async {
    _autoRestartEnabled = await _settings.getGatewayAutoRestart() ?? true;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> setAutoRestart(bool enabled) async {
    _autoRestartEnabled = enabled;
    await _settings.setGatewayAutoRestart(enabled);
    notifyListeners();
  }

  Future<bool> start() async {
    if (_state == GatewayState.running || _state == GatewayState.starting) {
      return true;
    }

    _state = GatewayState.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      final result =
          await Process.run('openclaw', ['gateway', 'start', '--json']);

      if (result.exitCode == 0) {
        _state = GatewayState.running;
        _startedAt = DateTime.now();
        _restartAttempts = 0;
        _startHealthCheck();
        notifyListeners();
        return true;
      } else {
        _state = GatewayState.error;
        _errorMessage = result.stderr.toString();
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = GatewayState.error;
      _errorMessage = 'Failed to start gateway: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> stop() async {
    if (_state == GatewayState.stopped ||
        _state == GatewayState.stopping ||
        _state == GatewayState.unknown) {
      return true;
    }

    _state = GatewayState.stopping;
    notifyListeners();

    try {
      final result =
          await Process.run('openclaw', ['gateway', 'stop', '--json']);

      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;

      if (result.exitCode == 0) {
        _state = GatewayState.stopped;
        _startedAt = null;
        notifyListeners();
        return true;
      } else {
        _state = GatewayState.error;
        _errorMessage = result.stderr.toString();
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = GatewayState.error;
      _errorMessage = 'Failed to stop gateway: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restart() async {
    await stop();
    return await start();
  }

  Future<void> checkStatus() async {
    try {
      final result =
          await Process.run('openclaw', ['gateway', 'status', '--json']);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        if (output.contains('running') || output.contains('active')) {
          if (_state != GatewayState.running) {
            _state = GatewayState.running;
            _startedAt ??= DateTime.now();
            _startHealthCheck();
            notifyListeners();
          }
        } else {
          if (_state != GatewayState.stopped) {
            _state = GatewayState.stopped;
            _healthCheckTimer?.cancel();
            notifyListeners();
          }
        }
      } else {
        if (_state != GatewayState.stopped) {
          _state = GatewayState.stopped;
          _healthCheckTimer?.cancel();
          notifyListeners();
        }
      }
    } catch (e) {
      if (_state != GatewayState.unknown) {
        _state = GatewayState.unknown;
        _errorMessage = 'Failed to check status: $e';
        notifyListeners();
      }
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await checkStatus();

      // Auto-restart on crash if enabled
      if (_autoRestartEnabled && _state != GatewayState.running) {
        final wasPreviouslyRunning = _startedAt != null;
        if (wasPreviouslyRunning && _restartAttempts < _maxRestartAttempts) {
          _restartAttempts++;
          _errorMessage =
              'Gateway crashed, attempting auto-restart ($_restartAttempts/$_maxRestartAttempts)';
          notifyListeners();

          // Wait a bit before restarting to avoid rapid restart loops
          await Future.delayed(Duration(seconds: _restartAttempts * 2));

          final success = await start();
          if (success) {
            _restartAttempts = 0; // Reset counter on successful restart
          }
        } else if (_restartAttempts >= _maxRestartAttempts) {
          _errorMessage =
              'Gateway failed to restart after $_maxRestartAttempts attempts. Auto-restart disabled.';
          _autoRestartEnabled = false;
          notifyListeners();
        }
      }
    });
  }

  Future<Map<String, dynamic>> getStatus() async {
    await checkStatus();
    return {
      'state': _state.name,
      'isRunning': isRunning,
      'startedAt': _startedAt?.toIso8601String(),
      'errorMessage': _errorMessage,
    };
  }

  @override
  void dispose() {
    _isDisposed = true;
    _healthCheckTimer?.cancel();
    if (_connectionManager != null) {
      _connectionManager!.removeListener(_onConnectionChanged);
    }
    super.dispose();
  }
}
