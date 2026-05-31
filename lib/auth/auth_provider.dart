import 'dart:async';
import '../models/user_model.dart';

/// Abstract interface for authentication providers
abstract class AuthProvider {
  /// Stream of authentication state changes
  Stream<bool> get authStateChanges;

  /// Get current user if authenticated
  UserModel? get currentUser;

  /// Get current access token
  Future<String?> getAccessToken();

  /// Initialize the provider
  Future<void> initialize();

  /// Login
  Future<void> login();

  /// Logout
  Future<void> logout();

  /// Handle auth callback (if required by provider)
  Future<bool> handleCallback({String? url});

  /// Mock/Developer login for testing purposes
  Future<void> loginMockDeveloper();
}
