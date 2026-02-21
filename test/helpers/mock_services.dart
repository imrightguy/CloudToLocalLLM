/// Mock services for testing
///
/// Provides mock implementations of core services for use in property-based
/// and integration tests. These mocks allow tests to run in isolation without
/// requiring full service initialization.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:get_it/get_it.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/admin_center_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/models/user_model.dart';
import 'package:cloudtolocalllm/models/admin_role_model.dart';

/// Initialize mock plugins for testing
Future<void> initializeMockPlugins() async {
  // Set up SharedPreferences mock
  // Set up SharedPreferences mock
  SharedPreferences.setMockInitialValues({});

  // Reset and setup GetIt
  final locator = GetIt.instance;
  await locator.reset();

  // Register basic mocks needed by most screens
  locator.registerSingleton<SettingsPreferenceService>(
      SettingsPreferenceService());

  // Register MockAuthService
  final authService = MockAuthService();
  locator.registerSingleton<AuthService>(
      authService as AuthService); // Cast using shim if needed, or implementer

  // Register MockAdminCenterService
  final adminService = MockAdminCenterService();
  locator.registerSingleton<AdminCenterService>(
      adminService as AdminCenterService);

  // Register PlatformAdapter
  locator.registerSingleton<PlatformAdapter>(
      PlatformAdapter(PlatformDetectionService()));
}

/// Mock JWT Service for testing
class MockJWTService {
  bool isAuthenticated = false;
  String? accessToken;
  String? idToken;
  Map<String, dynamic>? userProfile;

  Future<void> login() async {
    isAuthenticated = true;
    accessToken = 'mock_access_token';
    idToken = 'mock_id_token';
    userProfile = {
      'sub': 'mock_user_id',
      'email': 'test@example.com',
      'name': 'Test User',
    };
  }

  Future<void> logout() async {
    isAuthenticated = false;
    accessToken = null;
    idToken = null;
    userProfile = null;
  }
}

/// Mock Session Storage for testing
class MockSessionStorage {
  final Map<String, String> _storage = {};

  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  Future<String?> read({required String key}) async {
    return _storage[key];
  }

  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }

  Future<void> deleteAll() async {
    _storage.clear();
  }
}

/// Mock AuthService for testing
class MockAuthService extends ChangeNotifier implements AuthService {
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _areAuthenticatedServicesLoaded =
      ValueNotifier<bool>(false);
  final Completer<void> _sessionBootstrapCompleter = Completer<void>();

  String? _accessToken;
  UserModel? _currentUser;

  @override
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;

  @override
  ValueNotifier<bool> get isLoading => _isLoading;

  @override
  ValueNotifier<bool> get areAuthenticatedServicesLoaded =>
      _areAuthenticatedServicesLoaded;

  @override
  bool get isSessionBootstrapComplete => true;

  @override
  Future<void> get sessionBootstrapFuture => Future.value();

  @override
  UserModel? get currentUser => _currentUser;

  @override
  String get assistantName => 'Test Assistant';

  // Platform getters - default to false/mock
  @override
  bool get isWeb => false;

  @override
  Future<void> init() async {
    _sessionBootstrapCompleter.complete();
  }

  @override
  Future<void> login() async {
    _isAuthenticated.value = true;
    _accessToken = 'mock_access_token';
    _currentUser = UserModel(
      id: 'mock_user_id',
      email: 'christopher.maltais@gmail.com',
      name: 'Test User',
      picture: 'https://example.com/avatar.png',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    _isAuthenticated.value = false;
    _accessToken = null;
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> checkSession() async {
    return _isAuthenticated.value;
  }

  @override
  Future<String?> getAccessToken() async {
    return _accessToken;
  }

  @override
  Future<String?> getValidatedAccessToken() async {
    return _accessToken;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock AdminCenterService for testing
class MockAdminCenterService extends ChangeNotifier
    implements AdminCenterService {
  final bool _isLoading = false;
  String? _error;
  final List<AdminRoleModel> _adminRoles = [];
  Map<String, dynamic>? _dashboardMetrics;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get isInitialized => true;

  @override
  List<AdminRoleModel> get adminRoles => _adminRoles;

  @override
  Map<String, dynamic>? get dashboardMetrics => _dashboardMetrics;

  @override
  Future<void> initialize() async {
    // No-op
  }

  @override
  bool hasPermission(AdminPermission permission) {
    return true; // Grant all permissions for testing by default
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Creates a mock AuthService with optional authentication state
MockAuthService createMockAuthService({bool authenticated = false}) {
  final service = MockAuthService();
  if (authenticated) {
    service.login();
  }
  return service;
}

/// Creates a mock AdminCenterService
MockAdminCenterService createMockAdminCenterService() {
  return MockAdminCenterService();
}

/// Mock PlatformDetectionService for testing
class MockPlatformDetectionService extends PlatformDetectionService {
  bool _isWeb = false;
  bool _isAndroid = false;
  bool _isIOS = false;
  bool _isWindows = false;
  bool _isLinux = false;
  bool _isMacOS = false;

  @override
  bool get isWeb => _isWeb;
  @override
  bool get isWindows => _isWindows;
  @override
  bool get isLinux => _isLinux;
  @override
  bool get isMacOS => _isMacOS;
  @override
  bool get isMobile => _isAndroid || _isIOS;
  @override
  bool get isDesktop => _isWindows || _isLinux || _isMacOS;

  void setPlatform({
    bool isWeb = false,
    bool isAndroid = false,
    bool isIOS = false,
    bool isWindows = false,
    bool isLinux = false,
    bool isMacOS = false,
  }) {
    _isWeb = isWeb;
    _isAndroid = isAndroid;
    _isIOS = isIOS;
    _isWindows = isWindows;
    _isLinux = isLinux;
    _isMacOS = isMacOS;
    notifyListeners();
  }
}

/// Mock PlatformAdapter for testing
class MockPlatformAdapter extends PlatformAdapter {
  MockPlatformAdapter() : super(MockPlatformDetectionService());
}
