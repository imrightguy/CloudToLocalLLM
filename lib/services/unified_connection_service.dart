import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection_manager_service.dart';

/// Service that provides a unified view of all available AI connections.
class UnifiedConnectionService extends ChangeNotifier {
  ConnectionManagerService? _connectionManager;

  bool _isConnected = false;
  String _connectionType = 'none';
  String? _version;
  List<String> _models = [];
  String? _error;

  bool get isConnected => _isConnected;
  String get connectionType => _connectionType;
  String? get version => _version;
  List<String> get models => _models;
  String? get error => _error;

  void setConnectionManager(ConnectionManagerService connectionManager) {
    _connectionManager?.removeListener(_updateStatus);
    _connectionManager = connectionManager;
    _connectionManager!.addListener(_updateStatus);
    _updateStatus();
  }

  void _updateStatus() {
    if (_connectionManager == null) return;

    final isConnected = _connectionManager!.isConnected;
    _isConnected = isConnected;
    _connectionType = isConnected ? 'openclaw' : 'none';
    _version = isConnected ? 'OpenClaw Gateway' : null;
    _models = _connectionManager!.availableModels;

    if (!isConnected) {
      _error = 'OpenClaw Gateway disconnected';
    } else {
      _error = null;
    }

    notifyListeners();
  }

  Future<void> initialize() async {
    _updateStatus();
  }

  Future<void> refreshConnectionStatus() async {
    _updateStatus();
  }

  Future<void> reconnect() async {
    await _connectionManager?.reconnectAll();
  }

  @override
  void dispose() {
    _connectionManager?.removeListener(_updateStatus);
    super.dispose();
  }
}
