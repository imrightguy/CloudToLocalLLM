import 'dart:async';
import 'package:flutter/foundation.dart';
import '../di/locator.dart' as di;
import 'connection_manager_service.dart';

/// Service responsible for bootstrapping authenticated services after user authentication
class SessionBootstrapService {
  final Completer<void> _sessionBootstrapCompleter = Completer<void>();
  final ValueNotifier<bool> _areAuthenticatedServicesLoaded =
      ValueNotifier<bool>(false);

  bool _isRestoringSession = false;

  /// Initialize the session bootstrap process
  Future<void> initialize() async {
    _isRestoringSession = true;
    try {
      // Add timeout to prevent endless loading
      await _loadAuthenticatedServices().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint(
              '[SessionBootstrapService] TIMEOUT: Force setting services loaded = true');
          _areAuthenticatedServicesLoaded.value = true;
        },
      );
    } catch (e) {
      debugPrint(
          '[SessionBootstrapService] ERROR: $e - forcing services loaded = true');
      _areAuthenticatedServicesLoaded.value = true;
    } finally {
      _isRestoringSession = false;
      _completeSessionBootstrap();
    }
  }

  /// Load authenticated services after authentication is confirmed
  Future<void> _loadAuthenticatedServices() async {
    try {
      debugPrint('[SessionBootstrapService] Loading authenticated services...');

      final hasConnectionManager =
          di.serviceLocator.isRegistered<ConnectionManagerService>();

      if (hasConnectionManager) {
        _areAuthenticatedServicesLoaded.value = true;
        return;
      }

      debugPrint(
          '[SessionBootstrapService] Calling setupAuthenticatedServices...');
      await di.setupAuthenticatedServices();
      debugPrint(
          '[SessionBootstrapService] setupAuthenticatedServices returned');

      // Verify they were actually registered before setting the flag
      final registered =
          di.serviceLocator.isRegistered<ConnectionManagerService>();
      if (registered) {
        _areAuthenticatedServicesLoaded.value = true;
      } else {
        debugPrint(
            '[SessionBootstrapService] setupAuthenticatedServices returned but ConnectionManagerService is not registered');
      }
    } catch (e) {
      debugPrint(
          '[SessionBootstrapService] ERROR: Failed to load authenticated services: $e');
      _areAuthenticatedServicesLoaded.value = false;
    }
  }

  void _completeSessionBootstrap() {
    if (!_sessionBootstrapCompleter.isCompleted) {
      _sessionBootstrapCompleter.complete();
    }
  }

  /// Reset the bootstrap state (for logout)
  void reset() {
    _areAuthenticatedServicesLoaded.value = false;
    // Note: We don't reset the completer as it's a one-time operation per session
  }

  // Getters
  ValueNotifier<bool> get areAuthenticatedServicesLoaded =>
      _areAuthenticatedServicesLoaded;
  bool get isSessionBootstrapComplete => _sessionBootstrapCompleter.isCompleted;
  Future<void> get sessionBootstrapFuture => _sessionBootstrapCompleter.future;
  bool get isRestoringSession => _isRestoringSession;
}
