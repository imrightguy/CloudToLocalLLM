import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'auth_logger.dart';

/// Web-specific authentication service using direct Auth0 redirect
class AuthServiceWeb extends ChangeNotifier {
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;

  AuthServiceWeb() {
    AuthLogger.initialize();
    AuthLogger.info('AuthServiceWeb constructor called');
    _initialize();
  }

  /// Initialize authentication service
  Future<void> _initialize() async {
    AuthLogger.info('Web authentication service initializing');
    try {
      _isLoading.value = true;
      notifyListeners();
      AuthLogger.debug('Loading state set to true during initialization');

      // Check for existing authentication
      await _checkAuthenticationStatus();
      AuthLogger.info('Authentication service initialized successfully');
    } catch (e) {
      AuthLogger.error('Error initializing Auth0', {'error': e.toString()});
    } finally {
      _isLoading.value = false;
      notifyListeners();
      AuthLogger.debug('Loading state set to false after initialization');
    }
  }

  /// Check current authentication status
  Future<void> _checkAuthenticationStatus() async {
    try {
      // For now, we'll implement a simple check
      // In a production app, you'd check for stored tokens
      _isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      _isAuthenticated.value = false;
    }
  }

  /// Login using Auth0 redirect flow
  Future<void> login() async {
    AuthLogger.info('🔐 Web login method called');
    AuthLogger.logAuthStateChange(false, 'Login attempt started');

    try {
      _isLoading.value = true;
      notifyListeners();
      AuthLogger.debug('🔐 Loading state set to true');

      // For web, redirect directly to Auth0 login page
      final redirectUri = AppConfig.auth0WebRedirectUri;
      final state = DateTime.now().millisecondsSinceEpoch.toString();

      AuthLogger.info('🔐 Building Auth0 URL', {
        'redirectUri': redirectUri,
        'state': state,
        'domain': AppConfig.auth0Domain,
        'clientId': AppConfig.auth0ClientId,
        'audience': AppConfig.auth0Audience,
        'scopes': AppConfig.auth0Scopes,
      });

      final authUrl = Uri.https(
        AppConfig.auth0Domain,
        '/authorize',
        {
          'client_id': AppConfig.auth0ClientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': AppConfig.auth0Scopes.join(' '),
          'audience': AppConfig.auth0Audience,
          'state': state,
        },
      );

      AuthLogger.info('🔐 Auth0 URL constructed', {
        'url': authUrl.toString(),
        'length': authUrl.toString().length,
      });

      // For web, redirect the current window to Auth0
      try {
        AuthLogger.info('🔐 Attempting window.location.href redirect');
        web.window.location.href = authUrl.toString();
        AuthLogger.info('🔐 Redirect initiated successfully');

        // Add a small delay to ensure the redirect happens
        await Future.delayed(const Duration(milliseconds: 100));
        AuthLogger.warning(
            '🔐 Still executing after redirect - this should not happen');
      } catch (redirectError) {
        AuthLogger.error('🔐 Primary redirect failed', {
          'error': redirectError.toString(),
          'errorType': redirectError.runtimeType.toString(),
        });

        // Fallback: try using window.open with _self
        try {
          AuthLogger.info('🔐 Attempting fallback redirect with window.open');
          web.window.open(authUrl.toString(), '_self');
          AuthLogger.info('🔐 Fallback redirect initiated');
        } catch (fallbackError) {
          AuthLogger.error('🔐 Fallback redirect also failed', {
            'error': fallbackError.toString(),
            'errorType': fallbackError.runtimeType.toString(),
          });
          throw 'Both redirect methods failed: $redirectError, $fallbackError';
        }
      }
    } catch (e) {
      AuthLogger.error('🔐 Login error', {
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'stackTrace': StackTrace.current.toString(),
      });
      _isAuthenticated.value = false;
      AuthLogger.logAuthStateChange(false, 'Login failed with error');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
      AuthLogger.debug('🔐 Login method finally block executed');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Clear local state
      _currentUser = null;
      _isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Logout error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Handle Auth0 callback
  Future<bool> handleCallback() async {
    try {
      // For web, the callback is handled by the redirect
      // This is a placeholder for future token processing
      debugPrint('Web callback handling - checking authentication state');

      // In a real implementation, you would:
      // 1. Extract the authorization code from the URL
      // 2. Exchange it for tokens
      // 3. Store the tokens securely
      // 4. Load user profile

      return _isAuthenticated.value;
    } catch (e) {
      debugPrint('Callback handling error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
