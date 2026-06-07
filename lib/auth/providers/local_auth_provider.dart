import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import '../auth_provider.dart';

/// Local-only auth provider that creates an instant local profile.
/// No cloud dependencies, no network calls, no Auth0.
/// The local app is free to download and use — this makes that true.
class LocalAuthProvider extends AuthProvider {
  UserModel? _currentUser;
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<String?> getAccessToken() async => 'local-token';

  @override
  Future<void> initialize() async {
    debugPrint('[LocalAuthProvider] Initializing local-only auth...');
    _currentUser = UserModel(
      id: 'local-user',
      email: 'local@cloudtolocalllm.local',
      name: 'Local User',
      nickname: 'local',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _authStateController.add(true);
    debugPrint('[LocalAuthProvider] Local auth ready — no cloud required');
  }

  @override
  Future<void> login() async {
    // Already authenticated locally
    debugPrint('[LocalAuthProvider] Login: already authenticated');
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _authStateController.add(false);
    debugPrint('[LocalAuthProvider] Logged out');
  }

  @override
  Future<bool> handleCallback({String? url}) async => true;

  @override
  Future<void> loginMockDeveloper() async {
    // Same as init — local mode doesn't need mock
    await initialize();
  }
}
