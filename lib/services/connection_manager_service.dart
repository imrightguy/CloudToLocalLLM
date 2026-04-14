library services.connection_manager;

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/hermes_manager/hermes_manager.dart';
import '../services/hermes_manager/hermes_streaming_service.dart';
import '../services/openclaw_manager/gateway_control_service.dart';
import '../services/openclaw_manager/connection_manager_service.dart' as openclaw;

final Logger _log = Logger('ConnectionManagerService');

/// Manages connections to different backend gateways (OpenClaw, Hermes, etc.).
///
/// This service allows switching between different LLM gateway backends.
class ConnectionManagerService {
  /// The current backend type.
  BackendType get currentBackend => _currentBackend;
  BackendType _currentBackend = BackendType.openclaw;

  /// The OpenClaw gateway control service.
  final openclaw.GatewayControlService openclawGatewayService;

  /// The Hermes gateway control service.
  final HermesGatewayControlService hermesGatewayService;

  /// The OpenClaw streaming service (for WebSocket connections).
  openclaw.CloudStreamingService? _openclawStreamingService;

  /// The Hermes streaming service.
  HermesStreamingService? _hermesStreamingService;

  /// Create a new connection manager service.
  ConnectionManagerService({
    required this.openclawGatewayService,
    required this.hermesGatewayService,
  });

  /// Connect to the current backend.
  ///
  /// Returns a stream of responses from the backend.
  Stream<Map<String, dynamic>> connect({
    String? hermesUrl,
    String? hermesApiKey,
    String? model,
  }) {
    switch (_currentBackend) {
      case BackendType.openclaw:
        return _connectToOpenClaw();
      case BackendType.hermes:
        return _connectToHermes(hermesUrl, hermesApiKey, model ?? 'hermes/model');
    }
  }

  Stream<Map<String, dynamic>> _connectToOpenClaw() {
    _log.info('Connecting to OpenClaw gateway');
    // Implementation for OpenClaw connection
    // This would use the existing OpenClaw streaming service
    throw UnimplementedError('OpenClaw connection not implemented in this example');
  }

  Stream<Map<String, dynamic>> _connectToHermes(
    String? hermesUrl,
    String? hermesApiKey,
    String model,
  ) {
    _log.info('Connecting to Hermes gateway');
    _hermesStreamingService = HermesStreamingService(
      baseUrl: hermesUrl ?? 'ws://localhost',
      port: 1337,
      model: model,
      apiKey: hermesApiKey ?? '',
    );

    try {
      _hermesStreamingService!.connect();
      return _hermesStreamingService!.responseStream;
    } catch (e, st) {
      _log.severe('Failed to connect to Hermes', e, st);
      rethrow;
    }
  }

  /// Switch the current backend.
  void switchBackend(BackendType newBackend) {
    _log.info('Switching backend from $_currentBackend to $newBackend');
    _currentBackend = newBackend;
  }

  /// Get the current backend type.
  BackendType getBackend() => _currentBackend;

  /// Close all connections.
  void close() {
    _hermesStreamingService?.close();
    _openclawStreamingService?.close();
  }

  /// Initialize the connection manager.
  ///
  /// This sets up any necessary state before connecting to backends.
  Future<void> initialize() async {
    _log.info('Initializing ConnectionManagerService');
    // Perform any required setup here
    // For now, just log that initialization is complete
    _log.fine('ConnectionManagerService initialized');
  }
}

/// Supported backend types.
enum BackendType {
  openclaw,
  hermes,
}