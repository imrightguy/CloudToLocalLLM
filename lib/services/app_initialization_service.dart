import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'connection_manager_service.dart';
import 'desktop_client_detection_service.dart';
import '../utils/logger.dart';

/// Service that manages the initialization order of other services
/// Ensures services that require authentication are only initialized after login
class AppInitializationService extends ChangeNotifier {
  final AuthService _authService;
  bool _isInitialized = false;
  bool _isInitializing = false;

  AppInitializationService({
    required AuthService authService,
  }) : _authService = authService {
    // Listen for auth state changes
    _authService.addListener(_onAuthStateChanged);

    // If already authenticated or on Desktop, initialize immediately
    if (_authService.isAuthenticated.value || !kIsWeb) {
      _initializeServices();
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    appLogger.debug(
        '[AppInit] _onAuthStateChanged called. isAuthenticated: ${_authService.isAuthenticated.value}, isInitialized: $_isInitialized, isInitializing: $_isInitializing');
    if (_authService.isAuthenticated.value &&
        !_isInitialized &&
        !_isInitializing) {
      appLogger.info('[AppInit] User authenticated, initializing services...');
      _initializeServices();
    } else if (!_authService.isAuthenticated.value && _isInitialized) {
      appLogger
          .debug('[AppInit] User logged out, resetting initialization state');
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// Initialize services that require authentication
  Future<void> _initializeServices() async {
    if (_isInitializing || _isInitialized) return;

    _isInitializing = true;
    appLogger
        .debug('[AppInit] _isInitializing set to true, notifying listeners.');
    notifyListeners();

    try {
      appLogger.debug('[AppInit] Starting service initialization...');

      // Note: We can't access context here, so services need to be initialized
      // when this service is consumed by widgets that have access to context

      _isInitialized = true;
      appLogger.debug(
          '[AppInit] Service initialization completed, _isInitialized set to true.');
    } catch (e) {
      appLogger.error('[AppInit] Service initialization failed', error: e);
    } finally {
      _isInitializing = false;
      appLogger.debug(
          '[AppInit] _isInitializing set to false, notifying listeners.');
      notifyListeners();
    }
  }

  /// Initialize services with context (called from widget)
  Future<void> initializeWithContext(BuildContext context) async {
    appLogger.debug(
        '[AppInit] initializeWithContext called. isAuthenticated: ${_authService.isAuthenticated.value}, isInitialized: $_isInitialized');

    // Allow initialization without auth on Desktop
    final canInitialize = _authService.isAuthenticated.value || !kIsWeb;

    if (!canInitialize || _isInitialized) return;

    try {
      appLogger.debug('[AppInit] Initializing services with context...');

      // Check if authenticated services are available before trying to access them
      if (!context.mounted) {
        appLogger.debug(
            '[AppInit] Context not mounted, returning from initializeWithContext.');
        return;
      }

      ConnectionManagerService? connectionManager;
      DesktopClientDetectionService? clientDetection;

      try {
        connectionManager = context.read<ConnectionManagerService>();
      } catch (e) {
        appLogger.debug('[AppInit] ConnectionManagerService not yet available');
        return; // Services not loaded yet, wait for authentication
      }

      if (kIsWeb) {
        try {
          clientDetection = context.read<DesktopClientDetectionService>();
        } catch (e) {
          appLogger.debug(
              '[AppInit] DesktopClientDetectionService not yet available');
          return; // Services not loaded yet, wait for authentication
        }
      }

      // Initialize connection manager
      await connectionManager.initialize();

      // Initialize desktop client detection (web only)
      if (kIsWeb && clientDetection != null) {
        await clientDetection.initialize();
      }

      appLogger.debug('[AppInit] Context-based initialization completed');
    } catch (e) {
      appLogger.error('[AppInit] Context-based initialization failed',
          error: e);
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }
}
