import 'package:flutter/foundation.dart';
import 'connection_manager_service.dart';

/// Unified connection service that provides a consistent API for connections
///
/// This service integrates with the connection manager service to provide
/// a unified interface for both local Ollama and cloud connections.
class UnifiedConnectionService extends ChangeNotifier {
  ConnectionManagerService? _connectionManager;

  bool _isConnected = false;
  String? _version;
  List<String> _models = [];
  bool _isLoading = false;
  String? _error;
  String _connectionType = 'none';

  UnifiedConnectionService() {
    // Will be initialized when connection manager is available
  }

  /// Set the connection manager service reference
  void setConnectionManager(ConnectionManagerService connectionManager) {
    _connectionManager = connectionManager;

    // Listen to connection status changes
    _connectionManager!.addListener(_handleConnectionStatusChange);

    // Update initial status
    _handleConnectionStatusChange();
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get version => _version;
  List<String> get models => _models;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get connectionType => _connectionType;
  Map<String, dynamic> get connectionStatus =>
      _connectionManager?.getConnectionStatus() ?? {};

  /// Initialize the connection service
  Future<bool> initialize() async {
    if (_connectionManager == null) {
      debugPrint(
        '[UnifiedConnection] Connection manager not available, cannot initialize connection service',
      );
      return false;
    }

    // Get initial connection status
    await refreshConnectionStatus();
    return true;
  }

  /// Refresh connection status from connection manager
  Future<void> refreshConnectionStatus() async {
    if (_connectionManager == null) return;

    try {
      _setLoading(true);
      _clearError();

      _updateConnectionState();
    } catch (e) {
      _setError('Error refreshing connection status: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Handle connection status changes from connection manager
  void _handleConnectionStatusChange() {
    if (_connectionManager == null) return;

    _updateConnectionState();
  }

  /// Update connection state based on connection manager status
  void _updateConnectionState() {
    if (_connectionManager == null) {
      _isConnected = false;
      _connectionType = 'none';
      _version = null;
      _models = [];
      _setError('No connection manager available');
      return;
    }

    // Get connection status from connection manager
    final connectionType = _connectionManager!.getBestConnectionType();
    final status = _connectionManager!.getConnectionStatus();

    switch (connectionType) {
      case ConnectionType.local:
        _isConnected = true;
        _connectionType = 'local';
        _version = status['local']['version'] ?? 'Unknown';
        _models = List<String>.from(status['local']['models'] ?? []);
        _clearError();
        break;

      case ConnectionType.cloud:
        _isConnected = true;
        _connectionType = 'cloud';
        _version = 'Cloud Proxy';
        _models = _connectionManager!.availableModels;
        _clearError();
        break;

      case ConnectionType.none:
        _isConnected = false;
        _connectionType = 'none';
        _version = null;
        _models = [];

        // Set error message based on available statuses
        final localError = status['local']['error'];
        final cloudError = status['cloud']['error'];
        final errors = <String>[];

        if (localError != null) {
          errors.add('local: $localError');
        }
        if (cloudError != null) {
          errors.add('cloud: $cloudError');
        }

        if (errors.isNotEmpty) {
          _setError('Connection errors: ${errors.join(', ')}');
        } else {
          _setError('No connections available');
        }
        break;
    }

    notifyListeners();
  }

  /// Test connection by refreshing status
  Future<bool> testConnection() async {
    try {
      _setLoading(true);
      _clearError();

      if (_connectionManager != null) {
        await _connectionManager!.reconnectAll();
        await refreshConnectionStatus();
        return _isConnected;
      } else {
        _setError('Connection manager not available');
        return false;
      }
    } catch (e) {
      _setError('Connection test failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get available models (simplified - returns cached models)
  Future<List<String>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      // Return cached models from connection manager
      await refreshConnectionStatus();
      return _models;
    } catch (e) {
      _setError('Error loading models: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get best available connection type
  String? getBestConnection() {
    final connectionType = _connectionManager?.getBestConnectionType();
    return connectionType?.name;
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    debugPrint('[UnifiedConnection] Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionManager?.removeListener(_handleConnectionStatusChange);
    super.dispose();
  }
}

/// Model class for Ollama models
class OllamaModel {
  final String name;
  final String? tag;
  final int? size;
  final DateTime? modifiedAt;

  OllamaModel({required this.name, this.tag, this.size, this.modifiedAt});

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String,
      tag: json['tag'] as String?,
      size: json['size'] as int?,
      modifiedAt: json['modified_at'] != null
          ? DateTime.tryParse(json['modified_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'tag': tag,
      'size': size,
      'modified_at': modifiedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => name;
}
