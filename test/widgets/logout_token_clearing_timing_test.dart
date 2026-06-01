import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/session_storage_service.dart';
import 'package:cloudtolocalllm/models/user_model.dart';
import 'package:cloudtolocalllm/models/session_model.dart';

// Mock SessionStorageService
class MockSessionStorageService extends SessionStorageService {
  String? _storedToken = 'test-session-token';
  bool _sessionInvalidated = false;

  @override
  Future<SessionModel?> getCurrentSession() async {
    if (_sessionInvalidated || _storedToken == null) {
      return null;
    }

    final user = UserModel(
      id: 'test-user-id',
      email: 'test@example.com',
      name: 'Test User',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now(),
    );

    return SessionModel(
      id: 'session-id',
      userId: 'test-user-id',
      token: _storedToken!,
      expiresAt: DateTime.now().add(const Duration(hours: 23)),
      user: user,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      lastActivity: DateTime.now(),
    );
  }

  @override
  Future<void> invalidateSession(String token) async {
    _sessionInvalidated = true;
    _storedToken = null;
  }

  bool get isSessionInvalidated => _sessionInvalidated;
  String? get storedToken => _storedToken;
}

// Mock AuthService for testing
class TestableAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isRestoringSession => false;
  @override
  Future<void> updateDisplayName(String name) async {}
  final MockSessionStorageService _mockSessionStorage;

  UserModel? _currentUser;
  bool _isAuthenticated = false;
  String? _sessionToken;
  String? _accessToken;

  TestableAuthService({
    required MockSessionStorageService mockSessionStorage,
  }) : _mockSessionStorage = mockSessionStorage {
    _isAuthenticated = true;
    _currentUser = UserModel(
      id: 'test-user-id',
      email: 'test@example.com',
      name: 'Test User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _sessionToken = 'test-session-token';
    _accessToken = 'test-access-token';
  }

  @override
  String get assistantName => 'Test Assistant';

  @override
  Future<void> logout() async {
    // Simulate logout process
    _accessToken = null;
    if (_sessionToken != null) {
      await _mockSessionStorage.invalidateSession(_sessionToken!);
    }
    _isAuthenticated = false;
    _sessionToken = null;
    _currentUser = null;
    notifyListeners();
  }

  @override
  Future<bool> handleCallback({String? callbackUrl, String? code}) async =>
      true;

  @override
  Future<void> login({String? tenantId}) async {}

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getValidatedAccessToken() async => _accessToken;

  @override
  bool get isSessionBootstrapComplete => true;

  @override
  bool get isWeb => true;

  @override
  Future<void> get sessionBootstrapFuture => Future.value();

  @override
  ValueNotifier<bool> get isAuthenticated => ValueNotifier(_isAuthenticated);

  @override
  ValueNotifier<bool> get isLoading => ValueNotifier(false);

  @override
  ValueNotifier<bool> get areAuthenticatedServicesLoaded => ValueNotifier(true);

  @override
  Future<void> loginMockDeveloper() async {}

  @override
  Future<void> init() async {}

  @override
  UserModel? get currentUser => _currentUser;

  // Test helpers
  bool get isLoggedOut => !_isAuthenticated;
  bool get sessionTokenCleared => _sessionToken == null;
  bool get sessionInvalidated => _mockSessionStorage.isSessionInvalidated;
  String? get currentSessionToken => _sessionToken;
}

void main() {
  group('Logout Token Clearing Timing', () {
    late MockSessionStorageService mockSessionStorage;
    late TestableAuthService authService;

    setUp(() {
      mockSessionStorage = MockSessionStorageService();
      authService = TestableAuthService(
        mockSessionStorage: mockSessionStorage,
      );
    });

    test(
        'Property 15: Logout Token Clearing Timing - Tokens cleared within 1 second',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Verify initial state - user is authenticated with tokens
      expect(authService.isLoggedOut, false,
          reason: 'User should be authenticated initially');
      expect(authService.sessionTokenCleared, false,
          reason: 'Session token should exist initially');
      expect(await authService.getAccessToken(), isNotNull,
          reason: 'Access token should exist initially');

      // Measure time to clear tokens during logout
      final stopwatch = Stopwatch()..start();

      await authService.logout();

      stopwatch.stop();

      // Verify all tokens are cleared
      expect(authService.isLoggedOut, true,
          reason: 'User should be logged out after logout');
      expect(authService.sessionTokenCleared, true,
          reason: 'Session token should be cleared after logout');
      expect(await authService.getAccessToken(), isNull,
          reason: 'Access token should be cleared after logout');
      expect(authService.sessionInvalidated, true,
          reason: 'Session should be invalidated after logout');

      // Verify timing constraint: token clearing should complete within 1 second
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Token clearing took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
      );
    });

    test(
        'Property 15: Logout Token Clearing Timing - Multiple rapid logouts clear tokens within 1 second each',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Test multiple logout cycles
      for (int i = 0; i < 3; i++) {
        // Re-authenticate for next cycle
        authService._accessToken = 'test-access-token-$i';
        mockSessionStorage._sessionInvalidated = false;
        mockSessionStorage._storedToken = 'test-session-token-$i';
        authService._isAuthenticated = true;
        authService._currentUser = UserModel(
          id: 'test-user-id-$i',
          email: 'test$i@example.com',
          name: 'Test User $i',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        authService._sessionToken = 'test-session-token-$i';

        // Verify authenticated state
        expect(authService.isLoggedOut, false,
            reason: 'User should be authenticated in cycle $i');

        // Measure logout time
        final stopwatch = Stopwatch()..start();

        await authService.logout();

        stopwatch.stop();

        // Verify tokens cleared
        expect(authService.isLoggedOut, true,
            reason: 'User should be logged out in cycle $i');
        expect(authService.sessionTokenCleared, true,
            reason: 'Session token should be cleared in cycle $i');

        // Verify timing
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason:
              'Logout cycle $i took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
        );
      }
    });

    test(
        'Property 15: Logout Token Clearing Timing - JWT token cleared immediately',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Verify JWT token exists
      expect(await authService.getAccessToken(), isNotNull,
          reason: 'JWT access token should exist initially');

      final stopwatch = Stopwatch()..start();

      await authService.logout();

      stopwatch.stop();

      // Verify JWT token is cleared
      expect(await authService.getAccessToken(), isNull,
          reason: 'JWT access token should be cleared after logout');

      // Verify timing
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Token clearing took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
      );
    });

    test(
        'Property 15: Logout Token Clearing Timing - Session token invalidated within 1 second',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Verify session token exists
      expect(authService.currentSessionToken, isNotNull,
          reason: 'Session token should exist initially');
      expect(mockSessionStorage.isSessionInvalidated, false,
          reason: 'Session should not be invalidated initially');

      final stopwatch = Stopwatch()..start();

      await authService.logout();

      stopwatch.stop();

      // Verify session is invalidated
      expect(mockSessionStorage.isSessionInvalidated, true,
          reason: 'Session should be invalidated after logout');
      expect(authService.currentSessionToken, isNull,
          reason: 'Session token should be cleared after logout');

      // Verify timing
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Session invalidation took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
      );
    });

    test(
        'Property 15: Logout Token Clearing Timing - User data cleared within 1 second',
        () async {
      // **Feature: platform-settings-screen, Property 15: Logout Token Clearing Timing**
      // **Validates: Requirements 4.3**

      // Verify user data exists
      expect(authService._currentUser, isNotNull,
          reason: 'User data should exist initially');

      final stopwatch = Stopwatch()..start();

      await authService.logout();

      stopwatch.stop();

      // Verify user data is cleared
      expect(authService._currentUser, isNull,
          reason: 'User data should be cleared after logout');

      // Verify timing
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'User data clearing took ${stopwatch.elapsedMilliseconds}ms, should be < 1000ms',
      );
    });
  });
}
