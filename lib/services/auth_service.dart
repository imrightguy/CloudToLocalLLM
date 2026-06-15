import 'package:flutter/foundation.dart';

import '../models.dart';
import 'api_service.dart';

/// Simple auth state manager using [ChangeNotifier].
///
/// Wrap your widget tree with `ListenableBuilder` or `AnimatedBuilder`
/// keyed to [AuthNotifier.instance] to react to auth changes.
///
/// ```dart
/// ListenableBuilder(
///   listenable: AuthNotifier.instance,
///   builder: (context, _) {
///     if (AuthNotifier.instance.isLoggedIn) return HomeScreen();
///     return LoginScreen();
///   },
/// )
/// ```
class AuthNotifier extends ChangeNotifier {
  AuthNotifier._();
  static final AuthNotifier instance = AuthNotifier._();

  UserItem? _currentUser;

  /// `true` when a present, non-expired access token is held in memory.
  bool get isLoggedIn => ApiService.instance.hasToken;

  /// Cached user profile fetched from /auth/profile.
  UserItem? get currentUser => _currentUser;

  /// Load tokens from storage and optionally pre-fetch the profile.
  Future<void> init() async {
    await ApiService.instance.init();
    if (isLoggedIn) {
      try {
        _currentUser = await ApiService.instance.getProfile();
      } catch (_) {
        // Token may be expired; the auth gate will redirect to login.
      }
    }
    notifyListeners();
  }

  /// Convenience – login, cache profile, notify.
  Future<UserItem> login(
    String email,
    String password,
  ) async {
    final user = await ApiService.instance.login(email, password);
    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// Convenience – register, cache profile, notify.
  Future<UserItem> register(
    String firstName,
    String lastName,
    String email,
    String password, {
    String? role,
  }) async {
    final user = await ApiService.instance.register(
      firstName,
      lastName,
      email,
      password,
      role: role,
    );
    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// Logout – clear tokens & cached profile, notify.
  Future<void> logout() async {
    await ApiService.instance.logout();
    _currentUser = null;
    notifyListeners();
  }

  /// Force-refresh the cached profile from the server.
  Future<void> refreshProfile() async {
    _currentUser = await ApiService.instance.getProfile();
    notifyListeners();
  }

  /// Update the authenticated user's profile fields.
  /// PUT /auth/profile → returns updated user.
  Future<UserItem> updateProfile(
    Map<String, dynamic> updates,
  ) async {
    final result = await ApiService.instance.put('/auth/profile', updates);
    final data = result['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Réponse inattendue du serveur', code: 'MALFORMED_RESPONSE');
    }
    _currentUser = UserItem.fromJson(data);
    notifyListeners();
    return _currentUser!;
  }

  /// Change the authenticated user's password.
  /// PUT /auth/password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ApiService.instance.put('/auth/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
