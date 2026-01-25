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

  Future<bool>? _webInitFuture;

  @override
  Future<void> initialize() async {
    if (kIsWeb) {
      // Start processing web auth in background, but don't block initial load
      // This handles redirects and silent auth without hanging the app
      final currentUrl = web.window.location.href;
      final isCallback =
          currentUrl.contains('code=') && currentUrl.contains('state=');

      if (isCallback) {
        debugPrint(
            ' [Auth0] Callback URL detected, blocking init for exchange...');
        await handleCallback();
      } else {
        debugPrint(
            ' [Auth0] Normal load, starting silent init in background...');
        unawaited(handleCallback());
      }
    }

    // Always attempt to load from local storage immediately for fast startup
    await _loadFromStorage();
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    if (!kIsWeb) return true;

    // Use a singleton future to ensure we only init once
    _webInitFuture ??= _processWebAuth();
    return _webInitFuture!;
  }

  Future<bool> _processWebAuth() async {
    try {
      final currentUrl = web.window.location.href;
      final isCallback =
          currentUrl.contains('code=') && currentUrl.contains('state=');

      debugPrint(' [Auth0] Web auth processing... isCallback: $isCallback');

      final auth0Web = Auth0Web(_domain, _clientId,
          redirectUrl: '${web.window.location.origin}/callback');

      // onLoad() initializes the client.
      // We enable refresh tokens and local storage to prevent silent auth timeouts.
      final credentials = await auth0Web
          .onLoad(
        audience: _audience,
        scopes: {'openid', 'profile', 'email', 'offline_access'},
        useRefreshTokens: true,
        cacheLocation: CacheLocation.localStorage,
      )
          .timeout(
        Duration(seconds: isCallback ? 20 : 5),
        onTimeout: () {
          debugPrint(' [Auth0] onLoad() timed out');
          return null;
        },
      );

      if (credentials != null) {
        debugPrint(' [Auth0] Session authenticated via onLoad');
        await _storeCredentials(credentials);
        _currentUser = await _getUserFromIdToken(credentials.idToken);
        _authSubject.add(true);
        return true;
      }

      debugPrint(' [Auth0] No active session found via onLoad');
      return false;
    } catch (e) {
      debugPrint(' [Auth0] Web auth processing error: $e');
      return false;
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      if (_currentUser != null) {
        debugPrint(' [Auth0] Session already active, skipping storage load');
        return;
      }

      debugPrint(' [Auth0] Checking storage for existing session...');
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

      if (accessToken != null && _validateTokenSync(accessToken)) {
        if (userJson != null) {
          _currentUser = UserModel.fromJson(json.decode(userJson));
        } else if (idToken != null) {
          _currentUser = await _getUserFromIdToken(idToken);
        }

        if (_currentUser != null) {
          debugPrint(
              ' [Auth0] Session restored from storage for: ${_currentUser?.email}');
          _authSubject.add(true);
        }
      } else {
        debugPrint(' [Auth0] No valid session found in storage');
      }
    } catch (e) {
      debugPrint(' [Auth0] Storage load error: $e');
    }
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

  @override
  Future<void> login() async {
    await _mutex.protect(() async {
      try {
        if (kIsWeb) {
          debugPrint(' [Auth0] Login requested. Ensuring initialization...');
          // Ensure Auth0Client is initialized before calling loginWithRedirect
          await handleCallback();

          final auth0Web = Auth0Web(_domain, _clientId);
          debugPrint(' [Auth0] Initiating loginWithRedirect...');
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
    try {
      if (kIsWeb) {
        // Prefer the Auth0 SDK for token retrieval on Web as it handles rotation/caching
        final auth0Web = Auth0Web(_domain, _clientId);
        final credentials = await auth0Web.credentials().timeout(
              const Duration(seconds: 3),
              onTimeout: () =>
                  throw TimeoutException('SDK credentials timeout'),
            );
        if (credentials.accessToken.isNotEmpty) {
          return credentials.accessToken;
        }
      }
    } catch (e) {
      debugPrint(' [Auth0] SDK getAccessToken error/timeout: $e');
    }

    // Fallback to manual storage check
    String? token;
    if (kIsWeb) {
      token = web.window.localStorage.getItem('auth_access_token');
    } else {
      token = await _storage.read(key: 'access_token');
    }

    if (token != null && await _isTokenValid(token)) return token;

    // Auto refresh stub - implement full refresh logic
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

  void dispose() {
    _authSubject.close();
  }
}
