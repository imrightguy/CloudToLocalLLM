import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart'
    if (dart.library.io) 'auth0_flutter_stub.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:mutex/mutex.dart';
import 'package:web/web.dart' as web;
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
    if (kIsWeb) {
      try {
        final currentUrl = web.window.location.href;
        bool isCallback =
            currentUrl.contains('code=') && currentUrl.contains('state=');

        if (isCallback) {
          debugPrint(' [Auth0] Callback detected during initialization');
          // handleCallback will be called by CallbackScreen, but we can also handle it here
          // to ensure session is ready ASAP.
        } else {
          // Check manual storage first for speed
          final token = web.window.localStorage.getItem('auth_access_token');
          if (token != null && _validateTokenSync(token)) {
            debugPrint(' [Auth0] Session found in localStorage');
            await _loadFromStorage();
            if (_currentUser != null) return;
          }

          // Fallback to Auth0 silent check if needed, but with short timeout
          debugPrint(' [Auth0] Web silent initialization starting...');
          final auth0Web = Auth0Web(_domain, _clientId);
          await auth0Web.onLoad().timeout(
                const Duration(seconds: 3),
                onTimeout: () => null,
              );
        }
      } catch (e) {
        debugPrint(' [Auth0] Web init error: $e');
      }
    }
    await _loadFromStorage();
  }

  bool _validateTokenSync(String token) {
    try {
      if (JwtDecoder.isExpired(token)) return false;
      final payload = JwtDecoder.decode(token);
      final String iss = payload['iss']?.toString() ?? '';
      return iss.contains(_domain);
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      String? accessToken;
      String? idToken;
      String? userJson;

      if (kIsWeb) {
        accessToken = web.window.localStorage.getItem('auth_access_token');
        idToken = web.window.localStorage.getItem('auth_id_token');
        userJson = web.window.localStorage.getItem('auth_user_data');
      } else {
        accessToken = await _storage.read(key: 'access_token');
        idToken = await _storage.read(key: 'id_token');
        userJson = await _storage.read(key: 'user_data');
      }

      if (accessToken != null && await _isTokenValid(accessToken)) {
        if (userJson != null) {
          _currentUser = UserModel.fromJson(json.decode(userJson));
          _authSubject.add(true);
          debugPrint(' [Auth0] Session restored for: ${_currentUser?.email}');
        } else if (idToken != null) {
          _currentUser = await _getUserFromIdToken(idToken);
          _authSubject.add(true);
        }
      }
    } catch (e) {
      debugPrint('Auth0 load error: $e');
    }
  }

  Future<bool> _isTokenValid(String token) async {
    if (kIsWeb) {
      return _validateToken(
          {'token': token, 'domain': _domain, 'audience': _audience});
    }
    return await compute(_validateToken,
        {'token': token, 'domain': _domain, 'audience': _audience});
  }

  static bool _validateToken(Map<String, dynamic> params) {
    final token = params['token'] as String;
    try {
      if (JwtDecoder.isExpired(token)) return false;
      final payload = JwtDecoder.decode(token);
      final String iss = payload['iss']?.toString() ?? '';
      final domain = params['domain'] as String;
      return iss.contains(domain);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> login() async {
    await _mutex.protect(() async {
      try {
        if (kIsWeb) {
          final auth0Web = Auth0Web(_domain, _clientId);
          await auth0Web.loginWithRedirect(
            audience: _audience,
            scopes: {'openid', 'profile', 'email', 'offline_access'},
            redirectUrl: '${web.window.location.origin}/callback',
          );
          return;
        }

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
    if (kIsWeb) {
      web.window.localStorage
          .setItem('auth_access_token', credentials.accessToken);
      web.window.localStorage.setItem('auth_id_token', credentials.idToken);
      if (credentials.refreshToken != null) {
        web.window.localStorage
            .setItem('auth_refresh_token', credentials.refreshToken!);
      }
    } else {
      await _storage.write(key: 'access_token', value: credentials.accessToken);
      await _storage.write(key: 'id_token', value: credentials.idToken);
      if (credentials.refreshToken != null) {
        await _storage.write(
            key: 'refresh_token', value: credentials.refreshToken);
      }
    }

    final user = await _getUserFromIdToken(credentials.idToken);
    final userData = {
      'sub': user.id,
      'email': user.email,
      'name': user.name,
      'picture': user.picture,
      'nickname': user.nickname,
    };

    if (kIsWeb) {
      web.window.localStorage.setItem('auth_user_data', json.encode(userData));
    } else {
      await _storage.write(key: 'user_data', value: json.encode(userData));
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
        if (kIsWeb) {
          web.window.localStorage.removeItem('auth_access_token');
          web.window.localStorage.removeItem('auth_id_token');
          web.window.localStorage.removeItem('auth_user_data');
          web.window.localStorage.removeItem('auth_refresh_token');
          await Auth0Web(_domain, _clientId)
              .logout(returnToUrl: web.window.location.origin);
        } else {
          await _auth0.webAuthentication().logout();
          await _storage.deleteAll();
        }
        _currentUser = null;
        _authSubject.add(false);
      } catch (e) {
        debugPrint('Auth0 logout error: $e');
      }
    });
  }

  @override
  Future<String?> getAccessToken() async {
    String? token;
    if (kIsWeb) {
      token = web.window.localStorage.getItem('auth_access_token');
    } else {
      token = await _storage.read(key: 'access_token');
    }

    if (token != null && await _isTokenValid(token)) return token;

    String? refreshToken;
    if (kIsWeb) {
      refreshToken = web.window.localStorage.getItem('auth_refresh_token');
    } else {
      refreshToken = await _storage.read(key: 'refresh_token');
    }

    if (refreshToken != null) {
      token = await _refreshToken(refreshToken);
      if (token != null) {
        if (kIsWeb) {
          web.window.localStorage.setItem('auth_access_token', token);
        } else {
          await _storage.write(key: 'access_token', value: token);
        }
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
    if (kIsWeb) {
      try {
        debugPrint(' [Auth0] handleCallback() starting...');
        final auth0Web = Auth0Web(_domain, _clientId,
            redirectUrl: '${web.window.location.origin}/callback');

        final credentials = await auth0Web.onLoad();
        if (credentials != null) {
          await _storeCredentials(credentials);
          _currentUser = await _getUserFromIdToken(credentials.idToken);
          _authSubject.add(true);
          debugPrint(' [Auth0] Callback processed successfully');
          return true;
        }
        return false;
      } catch (e) {
        debugPrint(' [Auth0] Callback error: $e');
        return false;
      }
    }
    return true;
  }

  void dispose() {
    _authSubject.close();
  }
}
