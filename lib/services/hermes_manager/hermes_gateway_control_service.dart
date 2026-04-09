import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';

class HermesGatewayControlService extends ChangeNotifier {
  GatewayState _state = GatewayState.unknown;
  String? _errorMessage;
  DateTime? _connectedAt;
  Timer? _healthCheckTimer;
  final SettingsPreferenceService _settings;

  HermesGatewayControlService(this._settings);

  GatewayState get state => _state;
  String? get errorMessage => _errorMessage;
  DateTime? get connectedAt => _connectedAt;
  bool get isConnected => _state == GatewayState.running;

  Future<String> _getBaseUrl() async {
    final configuredUrl = await _settings.getHermesUrl();
    return (configuredUrl?.isNotEmpty ?? false)
        ? configuredUrl!
        : AppConfig.defaultHermesUrl;
  }

  Future<void> checkStatus() async {
    final baseUrl = await _getBaseUrl();
    try {
      final uri = Uri.parse('$baseUrl/health');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
              const Duration(seconds: 10),
            );

        if (response.statusCode == 200) {
          if (_state != GatewayState.running) {
            _state = GatewayState.running;
            _errorMessage = null;
            _connectedAt ??= DateTime.now();
            _startHealthCheck();
            notifyListeners();
            debugPrint(
                '[HermesGatewayControl] Connected to Hermes at $baseUrl');
          }
        } else {
          _setDisconnected('Health check returned status ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } on SocketException {
      _setDisconnected('Connection refused: Hermes not running at $baseUrl');
    } on TimeoutException {
      _setDisconnected('Connection timed out: Hermes not responding at $baseUrl');
    } catch (e) {
      if (_state != GatewayState.unknown) {
        _state = GatewayState.error;
        _errorMessage = 'Failed to check Hermes status: $e';
        notifyListeners();
      }
      debugPrint('[HermesGatewayControl] Status check error: $e');
    }
  }

  void _setDisconnected(String message) {
    if (_state != GatewayState.stopped) {
      _state = GatewayState.stopped;
      _errorMessage = message;
      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;
      notifyListeners();
    }
  }

  Future<bool> testConnection() async {
    final baseUrl = await _getBaseUrl();
    debugPrint(
        '[HermesGatewayControl] Testing connection to Hermes at $baseUrl');
    try {
      final uri = Uri.parse('$baseUrl/health');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
              const Duration(seconds: 10),
            );

        final success = response.statusCode == 200;
        if (success) {
          _state = GatewayState.running;
          _errorMessage = null;
          _connectedAt = DateTime.now();
          debugPrint(
              '[HermesGatewayControl] Connection test successful at $baseUrl');
        } else {
          _state = GatewayState.stopped;
          _errorMessage =
              'Health check returned status ${response.statusCode}';
          debugPrint(
              '[HermesGatewayControl] Connection test failed: status ${response.statusCode}');
        }
        notifyListeners();
        return success;
      } finally {
        client.close();
      }
    } on SocketException {
      _state = GatewayState.stopped;
      _errorMessage = 'Connection refused: Hermes not running at $baseUrl';
      notifyListeners();
      debugPrint(
          '[HermesGatewayControl] Connection test failed: not running at $baseUrl');
      return false;
    } on TimeoutException {
      _state = GatewayState.stopped;
      _errorMessage = 'Connection timed out: Hermes not responding';
      notifyListeners();
      debugPrint(
          '[HermesGatewayControl] Connection test failed: timeout');
      return false;
    } catch (e) {
      _state = GatewayState.error;
      _errorMessage = 'Connection test failed: $e';
      notifyListeners();
      debugPrint('[HermesGatewayControl] Connection test error: $e');
      return false;
    }
  }

  Stream<GatewayState> watchStatus() async* {
    yield _state;
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      await checkStatus();
      yield _state;
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await checkStatus();
    });
  }

  Future<Map<String, dynamic>> getStatus() async {
    await checkStatus();
    return {
      'state': _state.name,
      'isConnected': isConnected,
      'connectedAt': _connectedAt?.toIso8601String(),
      'errorMessage': _errorMessage,
    };
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    super.dispose();
  }
}
