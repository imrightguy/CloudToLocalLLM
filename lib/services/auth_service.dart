import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../auth/auth_provider.dart';

import 'session_bootstrap_service.dart';

/// Provider-Agnostic Authentication Service
class AuthService extends ChangeNotifier {
  final AuthProvider _authProvider;
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _areAuthenticatedServicesLoaded =
      ValueNotifier<bool>(false);
  final Completer<void> _sessionBootstrapCompleter = Completer<void>();

  bool _initialized = false;
  bool _isInitializing = false;
  Completer<void>? _initCompleter;
  bool _isRestoringSession = false;
  late final SessionBootstrapService _sessionBootstrapService;

  AuthService(this._authProvider) {
    debugPrint(
        '[AuthService] Constructor called with provider: ${_authProvider.runtimeType}');
    _sessionBootstrapService = SessionBootstrapService();
    // Sync the services loaded state
    _sessionBootstrapService.areAuthenticatedServicesLoaded.addListener(() {
      _areAuthenticatedServicesLoaded.value =
          _sessionBootstrapService.areAuthenticatedServicesLoaded.value;
      notifyListeners();
    });
  }

  Future<void> init() async {
    debugPrint('[AuthService] init() called');
    if (_initialized) return;
    if (_isInitializing) {
      return _initCompleter?.future ?? Future.value();
    }

    _isInitializing = true;
    _initCompleter = Completer<void>();

    try {
      await _initProvider();
      _initialized = true;
      _initCompleter?.complete();
      debugPrint('[AuthService] init() completed');
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Initialize Auth Provider
  Future<void> _initProvider() async {
    _isRestoringSession = true;
    try {
      _isLoading.value = true;
      notifyListeners();

      await _authProvider.initialize();
      debugPrint('[AuthService] Provider initialized');

      // Listen to auth state changes from provider
      _authProvider.authStateChanges.listen((isAuthenticated) async {
        debugPrint(
            '[AuthService] Provider auth state changed: $isAuthenticated');
        if (isAuthenticated) {
          final user = _authProvider.currentUser;
          if (user != null) {
            await _handleAuthenticatedUser(user);
          }
        } else {
          await _handleLogout();
        }
      });

      // Check initial state
      final currentUser = _authProvider.currentUser;
      if (currentUser != null) {
        debugPrint('[AuthService] Found current user, handling...');
        await _handleAuthenticatedUser(currentUser);
      } else {
        debugPrint('[AuthService] No current user found');
        // For desktop: set services loaded even without auth (local mode)
        if (!kIsWeb) {
          debugPrint('[AuthService] Desktop mode: setting services loaded = true for local use');
          _areAuthenticatedServicesLoaded.value = true;
        }
      }
    } catch (e) {
      debugPrint(' Failed to initialize Auth Provider: $e');
    } finally {
      _isRestoringSession = false;
      _isLoading.value = false;
      _completeSessionBootstrap();
      notifyListeners();
    }
  }

  Future<void> _handleAuthenticatedUser(UserModel user) async {
    if (_isAuthenticated.value) return;

    _isAuthenticated.value = true;
    notifyListeners();

    await _sessionBootstrapService.initialize();
    _areAuthenticatedServicesLoaded.value = true;
    debugPrint('[AuthService] Authenticated services loaded');
  }

  Future<void> _handleLogout() async {
    _isAuthenticated.value = false;
    
    if (kIsWeb) {
      _areAuthenticatedServicesLoaded.value = false;
    } else {
      // On Desktop, keep services loaded for local use
      debugPrint('[AuthService] User logged out on desktop, keeping services loaded for local use');
    }
    
    notifyListeners();
  }

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  ValueNotifier<bool> get areAuthenticatedServicesLoaded =>
      _areAuthenticatedServicesLoaded;
  bool get isSessionBootstrapComplete => _sessionBootstrapCompleter.isCompleted;
  Future<void> get sessionBootstrapFuture => _sessionBootstrapCompleter.future;
  bool get isRestoringSession => _isRestoringSession;
  UserModel? get currentUser => _authProvider.currentUser;

  String get assistantName {
    final user = currentUser;
    if (user == null) return 'Your AI Assistant';
    if (user.email == 'christopher.maltais@gmail.com' || user.email == 'chokesmaster@gmail.com' || user.email == 'dev@zoidbot.online') {
      return 'Zoidbot';
    }
    return '${user.name ?? 'Your'}\'s Assistant';
  }

  // Platform detection
  bool get isWeb => kIsWeb;

  /// Login
  Future<void> login() async {
    debugPrint(
        '[AuthService] login() called with provider: ${_authProvider.runtimeType}');
    _isLoading.value = true;
    notifyListeners();
    try {
      await _authProvider.login();
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();
      await _authProvider.logout();
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  Future<String?> getAccessToken() async => _authProvider.getAccessToken();

  Future<void> updateDisplayName(String name) async {
    // no-op for now unless provider supports it
  }

  /// Validates only if token exists (logic moved to provider ideally, but keeping signature)
  Future<String?> getValidatedAccessToken() async => getAccessToken();

  Future<bool> handleCallback({String? callbackUrl, String? code}) async {
    return _authProvider.handleCallback(url: callbackUrl);
  }

  void _completeSessionBootstrap() {
    if (!_sessionBootstrapCompleter.isCompleted) {
      _sessionBootstrapCompleter.complete();
    }
  }

  @override
  void dispose() {
    // Cancel any pending initialization
    if (_isInitializing && !_initCompleter!.isCompleted) {
      _initCompleter?.complete();
    }
    super.dispose();
  }
}
