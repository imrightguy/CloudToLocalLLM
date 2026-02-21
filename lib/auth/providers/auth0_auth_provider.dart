import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart'
    if (dart.library.io) 'auth0_flutter_stub.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:mutex/mutex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'auth_web_utils.dart';
import '../auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/app_config.dart';

class Auth0AuthProvider implements AuthProvider {
  static const String _domain = 'dev-vivn1fcgzi0c2czy.us.auth0.com';
  static const String _clientId = 'mm7lIRm33LGyoQ0FKCy04x88fsgnbvr1';
  static const String _audience = 'https://api.zoidbot.online';
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
      final currentUrl = authWebUtils.currentUrl ?? '';
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
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      _startLinuxCallbackListener();
    }

    await _loadFromStorage();
  }

  void _startLinuxCallbackListener() {
    debugPrint(' [Auth0] Starting Linux callback file listener');
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_currentUser != null) return;

      try {
        final tempDir = Directory.systemTemp;
        final callbackFile =
            File('${tempDir.path}/cloudtolocalllm_callback.txt');
        if (await callbackFile.exists()) {
          final url = await callbackFile.readAsString();
          debugPrint(' [Auth0] Found callback file with URL: $url');
          await callbackFile.delete();
          await _handleLinuxCallback(url);
        }
      } catch (e) {
        debugPrint(' [Auth0] Error checking callback file: $e');
      }
    });
  }

  @override
  Future<bool> handleCallback({String? url}) async {
    if (!kIsWeb) return true;
    _webInitFuture ??= _processWebAuth();
    return _webInitFuture!;
  }

  Future<bool> _processWebAuth() async {
    try {
      final auth0Web = Auth0Web(_domain, _clientId,
          redirectUrl: '${authWebUtils.origin}/callback');

      final credentials = await auth0Web
          .onLoad(
            audience: _audience,
            scopes: {'openid', 'profile', 'email', 'offline_access'},
            useRefreshTokens: true,
            cacheLocation: CacheLocation.localStorage,
          )
          .timeout(const Duration(seconds: 20));

      if (credentials != null) {
        await _storeCredentials(credentials);
        _currentUser = await _getUserFromIdToken(credentials.idToken);
        _authSubject.add(true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint(' [Auth0] Web auth processing error: $e');
      return false;
    }
  }

  Future<void> _loadFromStorage() async {
    // Dev Mode Auto-Login Bypass
    if (AppConfig.enableDevMode && !kIsWeb) {
      debugPrint(' [Auth0] Dev Mode enabled, simulating login...');
      _currentUser = UserModel(
        id: 'google-oauth2|102509433531341542550',
        email: 'dev@zoidbot.online',
        name: 'Christopher (Dev)',
        nickname: 'rightguy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _authSubject.add(true);
      return;
    }

    try {
      String? accessToken, idToken, userJson;
      if (kIsWeb) {
        accessToken = authWebUtils.getLocalStorageItem('auth_access_token');
        idToken = authWebUtils.getLocalStorageItem('auth_id_token');
        userJson = authWebUtils.getLocalStorageItem('auth_user_data');
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
        if (_currentUser != null) _authSubject.add(true);
      }
    } catch (e) {
      debugPrint(' [Auth0] Storage load error: $e');
    }
  }

  bool _validateTokenSync(String token) {
    try {
      if (JwtDecoder.isExpired(token)) return false;
      final payload = JwtDecoder.decode(token);
      return (payload['iss']?.toString() ?? '').contains(_domain);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> login() async {
    await _mutex.protect(() async {
      try {
        if (kIsWeb) {
          await handleCallback();
          await Auth0Web(_domain, _clientId).loginWithRedirect(
            audience: _audience,
            scopes: {'openid', 'profile', 'email', 'offline_access'},
            redirectUrl: '${authWebUtils.origin}/callback',
          );
          return;
        }

        if (defaultTargetPlatform == TargetPlatform.linux) {
          await _loginLinux();
          return;
        }

        final credentials =
            await _auth0.webAuthentication(scheme: _scheme).login(
          audience: _audience,
          scopes: {'openid', 'profile', 'email', 'offline_access'},
        );
        await _storeCredentials(credentials);
        _currentUser = await _getUserFromIdToken(credentials.idToken);
        _authSubject.add(true);
      } catch (e) {
        debugPrint('Auth0 login error: $e');
        rethrow;
      }
    });
  }

  Future<void> _loginLinux() async {
    debugPrint(' [Auth0] Starting Linux login flow (PKCE)');
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateRandomString(16);

    await _storage.write(key: 'linux_code_verifier', value: codeVerifier);
    await _storage.write(key: 'linux_auth_state', value: state);

    final redirectUri = '$_scheme://callback';
    final loginUrl = Uri.https(_domain, '/authorize', {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'scope': 'openid profile email offline_access',
      'audience': _audience,
      'state': state,
    });

    if (!await launchUrl(loginUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch login URL');
    }

    final appLinks = AppLinks();
    StreamSubscription? sub;
    sub = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == _scheme &&
          (uri.path == 'callback' || uri.host == 'callback')) {
        _handleLinuxCallback(uri.toString());
        sub?.cancel();
      }
    });
  }

  Future<void> _handleLinuxCallback(String url) async {
    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      final returnedState = uri.queryParameters['state'];
      if (code == null) return;

      final savedVerifier = await _storage.read(key: 'linux_code_verifier');
      final savedState = await _storage.read(key: 'linux_auth_state');

      if (savedState != null && returnedState != savedState) return;
      if (savedVerifier == null) return;

      await _storage.delete(key: 'linux_code_verifier');
      await _storage.delete(key: 'linux_auth_state');

      final response = await http.post(
        Uri.https(_domain, '/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'code_verifier': savedVerifier,
          'code': code,
          'redirect_uri': '$_scheme://callback',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _storage.write(key: 'access_token', value: data['access_token']);
        await _storage.write(key: 'id_token', value: data['id_token']);
        if (data['refresh_token'] != null) {
          await _storage.write(
              key: 'refresh_token', value: data['refresh_token']);
        }

        _currentUser = await _getUserFromIdToken(data['id_token']);
        final userData = {
          'sub': _currentUser!.id,
          'email': _currentUser!.email,
          'name': _currentUser!.name,
          'picture': _currentUser!.picture,
          'nickname': _currentUser!.nickname,
        };
        await _storage.write(key: 'user_data', value: json.encode(userData));
        _authSubject.add(true);
      }
    } catch (e) {
      debugPrint(' [Auth0] Error handling Linux callback: $e');
    }
  }

  String _generateRandomString(int length) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _generateCodeVerifier() => _generateRandomString(64);

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<void> _storeCredentials(Credentials credentials) async {
    if (kIsWeb) {
      authWebUtils.setLocalStorageItem(
          'auth_access_token', credentials.accessToken);
      authWebUtils.setLocalStorageItem('auth_id_token', credentials.idToken);
      if (credentials.refreshToken != null) {
        authWebUtils.setLocalStorageItem(
            'auth_refresh_token', credentials.refreshToken!);
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
      authWebUtils.setLocalStorageItem('auth_user_data', json.encode(userData));
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
          authWebUtils.removeLocalStorageItem('auth_access_token');
          authWebUtils.removeLocalStorageItem('auth_id_token');
          authWebUtils.removeLocalStorageItem('auth_user_data');
          authWebUtils.removeLocalStorageItem('auth_refresh_token');
          await Auth0Web(_domain, _clientId)
              .logout(returnToUrl: authWebUtils.origin ?? '');
        } else if (defaultTargetPlatform == TargetPlatform.linux) {
          await _storage.deleteAll();
          final logoutUrl = Uri.https(_domain, '/v2/logout', {
            'client_id': _clientId,
            'returnTo': '$_scheme://callback',
          });
          await launchUrl(logoutUrl, mode: LaunchMode.externalApplication);
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
        final auth0Web = Auth0Web(_domain, _clientId);
        final credentials =
            await auth0Web.credentials().timeout(const Duration(seconds: 3));
        if (credentials.accessToken.isNotEmpty) return credentials.accessToken;
      }
    } catch (e) {
      debugPrint(
          '[Auth0Provider] ⚠ Failed to get credentials from Auth0Web: $e');
      // Fall through to local storage retrieval
    }

    String? token;
    if (kIsWeb) {
      token = authWebUtils.getLocalStorageItem('auth_access_token');
    } else {
      token = await _storage.read(key: 'access_token');
    }

    if (token != null && await _isTokenValid(token)) return token;

    String? refreshToken;
    if (kIsWeb) {
      refreshToken = authWebUtils.getLocalStorageItem('auth_refresh_token');
    } else {
      refreshToken = await _storage.read(key: 'refresh_token');
    }

    if (refreshToken != null) {
      token = await _refreshToken(refreshToken);
      if (token != null) {
        if (kIsWeb) {
          authWebUtils.setLocalStorageItem('auth_access_token', token);
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
        return json.decode(response.body)['access_token'];
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
    return null;
  }

  Future<bool> _isTokenValid(String token) async {
    if (kIsWeb) return _validateToken({'token': token, 'domain': _domain});
    return await compute(_validateToken, {'token': token, 'domain': _domain});
  }

  static bool _validateToken(Map<String, dynamic> params) {
    try {
      final token = params['token'] as String;
      if (JwtDecoder.isExpired(token)) return false;
      final payload = JwtDecoder.decode(token);
      return (payload['iss']?.toString() ?? '')
          .contains(params['domain'] as String);
    } catch (_) {
      return false;
    }
  }

  void dispose() => _authSubject.close();
}
