import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:mutex/mutex.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';

class Auth0AuthProvider implements AuthProvider {
  static const String _domain = 'dev-vivn1fcgzi0c2czy.us.auth0.com';
  static const String _clientId = 'mm7lIRm33LGyoQ0FKCy04x88fsgnbvr1';
  static const String _audience = 'https://api.cloudtolocalllm.online';
  static const String _scheme = 'cloudtolocalllm';

  final Auth0 _auth0 = Auth0(_domain, _clientId);
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final BehaviorSubject<bool> _authSubject = BehaviorSubject.seeded(false);
  final Mutex _mutex = Mutex();

  @override
  Stream<bool> get authStateChanges => _authSubject.stream;

  @override
  UserModel? get currentUser => _currentUser;
  UserModel? _currentUser;

  @override
  Future<void> initialize() async {
    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken != null && await _isTokenValid(accessToken)) {
        final userJson = await _storage.read(key: 'user_data');
        if (userJson != null) {
          _currentUser = UserModel.fromJson(json.decode(userJson));
          _authSubject.add(true);
        }
      }
    } catch (e) {
      debugPrint('Auth0 load error: $e');
    }
  }

  Future<bool> _isTokenValid(String token) async {
    return await compute(_validateToken,
        {'token': token, 'domain': _domain, 'audience': _audience});
  }

  static bool _validateToken(Map<String, dynamic> params) {
    final token = params['token'] as String;
    if (JwtDecoder.isExpired(token)) return false;
    final payload = JwtDecoder.decode(token);
    final iss = payload['iss'];
    final aud = payload['aud'];
    final expectedIssuer = 'https://${params['domain']}/';
    final expectedAudience = params['audience'] as String?;

    // Check issuer
    if (iss != expectedIssuer) return false;

    // Check audience (can be string or list for API tokens)
    if (expectedAudience != null) {
      if (aud is String) {
        return aud == expectedAudience;
      } else if (aud is List) {
        return aud.contains(expectedAudience);
      }
    }
    return true;
  }

  @override
  Future<void> login() async {
    await _mutex.protect(() async {
      try {
        final credentials =
            await _auth0.webAuthentication(scheme: _scheme).login(
          audience: _audience,
          scopes: {'openid', 'profile', 'email', 'offline_access'},
        );
        await _storeCredentials(credentials);
        final user = await _getUserFromIdToken(credentials.idToken);
        _currentUser = user;
        _authSubject.add(true);
      } catch (e) {
        debugPrint('Auth0 login error: $e');
        rethrow;
      }
    });
  }

  Future<void> _storeCredentials(Credentials credentials) async {
    await _storage.write(key: 'access_token', value: credentials.accessToken);
    await _storage.write(key: 'id_token', value: credentials.idToken);
    if (credentials.refreshToken != null) {
      await _storage.write(
          key: 'refresh_token', value: credentials.refreshToken);
    }
  }

  Future<UserModel> _getUserFromIdToken(String idToken) async {
    final payload = JwtDecoder.decode(idToken);
    return UserModel(
      id: payload['sub'] as String,
      email: payload['email'] as String? ?? '',
      name: payload['name'] as String?,
      picture: payload['picture'] as String?,
      nickname: payload['nickname'] as String?,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> logout() async {
    await _mutex.protect(() async {
      try {
        await _auth0.webAuthentication().logout();
        await _storage.deleteAll();
        _currentUser = null;
        _authSubject.add(false);
      } catch (e) {
        debugPrint('Auth0 logout error: $e');
      }
    });
  }

  @override
  Future<String?> getAccessToken() async {
    String? token = await _storage.read(key: 'access_token');
    if (token != null && await _isTokenValid(token)) return token;
    // Auto refresh stub - implement full refresh logic
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      token = await _refreshToken(refreshToken);
      if (token != null) {
        await _storage.write(key: 'access_token', value: token);
        return token;
      }
    }
    return null;
  }

  Future<String?> _refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://$_domain/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'grant_type=refresh_token&client_id=$_clientId&refresh_token=$refreshToken',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
    return null;
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    // PKCE webview handles callback internally; desktop via main args
    return true;
  }

  void dispose() {
    _authSubject.close();
  }
}
