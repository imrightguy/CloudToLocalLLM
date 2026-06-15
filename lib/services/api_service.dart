import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models.dart';
import 'auth_token_storage.dart';

export 'package:http/http.dart' show MultipartFile;

/// Custom exception for API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
  });

  bool get isDuplicateAccount =>
      code == 'USER_ALREADY_EXISTS' ||
      code == 'USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL' ||
      message.toLowerCase().contains('already exists') ||
      message.toLowerCase().contains('already registered') ||
      statusCode == 409;

  bool get isInvalidCredentials =>
      code == 'INVALID_CREDENTIALS' ||
      code == 'INVALID_EMAIL_OR_PASSWORD' ||
      message.toLowerCase().contains('invalid credentials') ||
      message.toLowerCase().contains('invalid email or password');

  String get userFacingMessage {
    if (isDuplicateAccount) {
      return 'Un compte existe déjà pour cette adresse courriel.';
    }
    if (isInvalidCredentials) {
      return 'Courriel ou mot de passe invalide.';
    }
    if (code == 'ACCOUNT_INACTIVE') {
      return 'Compte inactif. Contactez votre administrateur.';
    }
    return message;
  }

  @override
  String toString() =>
      'ApiException: $message (status: $statusCode${code == null ? '' : ', code: $code'})';
}

/// Singleton HTTP client with JWT authentication.
///
/// Usage:
/// ```dart
/// await ApiService.instance.init();
/// final user = await ApiService.instance.login('a@b.com', 'pass');
/// ```
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String baseUrl = AppConfig.apiBaseUrl;

  /// Hard ceiling on any single HTTP round-trip so a stalled connection can
  /// never leave a request (or the UI awaiting it) pending forever.
  static const Duration _requestTimeout = Duration(seconds: 30);

  @visibleForTesting
  http.Client client = http.Client();

  String? _accessToken;
  String? _refreshToken;

  /// Whether tokens have been loaded from storage.
  bool _initialized = false;

  /// Initialise – load persisted tokens from browser or shared prefs.
  Future<void> init() async {
    if (_initialized) return;
    final tokens = await readAuthTokens();
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _initialized = true;

    // On web the access token only lives in memory and is gone after a reload,
    // while the refresh token persists as an HttpOnly cookie. Bootstrap a fresh
    // access token from that cookie so the session survives a page refresh.
    if (kUsesHttpOnlyRefreshCookie &&
        (_accessToken == null || _accessToken!.isEmpty)) {
      // Best-effort bootstrap. _tryRefresh now throws on transient network
      // errors (so a live request won't log the user out over a blip); during
      // startup we simply swallow that and let the auth gate decide.
      try {
        await _tryRefresh();
      } catch (_) {/* offline at startup — stay logged out for now */}
    }
  }

  // ---------------------------------------------------------------------------
  // Token helpers
  // ---------------------------------------------------------------------------

  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  String get accessToken => _accessToken ?? '';

  Map<String, String> getHeaders() => _getHeaders();

  Map<String, String> _getHeaders() => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<void> _persistTokens(String? access, String? refresh) async {
    _accessToken = access;
    // On web the refresh token is owned by the browser's HttpOnly cookie and
    // must never be held in JS-reachable memory or storage (XSS). On native it
    // is kept in memory and persisted via shared_preferences.
    _refreshToken = kUsesHttpOnlyRefreshCookie ? null : refresh;
    await writeAuthTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await clearAuthTokens();
  }

  // ---------------------------------------------------------------------------
  // Generic HTTP methods
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> get(String path) async => _request('GET', path);

  Future<Map<String, dynamic>> post(String path, Object? body) async =>
      _request('POST', path, body: body);

  Future<Map<String, dynamic>> put(String path, Object? body) async =>
      _request('PUT', path, body: body);

  Future<Map<String, dynamic>> patch(String path, Object? body) async =>
      _request('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path) async =>
      _request('DELETE', path);

  /// Core request handler with automatic 401-retry via refresh token.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await client
              .get(uri, headers: _getHeaders())
              .timeout(_requestTimeout);
          break;
        case 'POST':
          response = await client
              .post(uri, headers: _getHeaders(), body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        case 'PUT':
          response = await client
              .put(uri, headers: _getHeaders(), body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        case 'PATCH':
          response = await client
              .patch(uri, headers: _getHeaders(), body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        case 'DELETE':
          response = await client
              .delete(uri, headers: _getHeaders())
              .timeout(_requestTimeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      throw const ApiException(
        'La requête a expiré — réessayez',
        code: 'REQUEST_TIMEOUT',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException('Erreur réseau — vérifiez votre connexion');
    }

    // Decode JSON once
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Réponse invalide du serveur',
        statusCode: response.statusCode,
      );
    }

    // 401 → attempt token refresh (once)
    if (response.statusCode == 401 && !isRetry) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(method, path, body: body, isRetry: true);
      }
      // Refresh failed – force logout
      await _clearTokens();
      throw const ApiException('Session expirée — veuillez vous reconnecter');
    }

    // Non-2xx error
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorPayload = data['error'];
      final errorMsg = errorPayload is Map
          ? errorPayload['message'] ?? errorPayload.toString()
          : data['message'] ?? 'Erreur ${response.statusCode}';
      final errorCode = errorPayload is Map
          ? errorPayload['code']?.toString()
          : data['code']?.toString();
      throw ApiException(
        errorMsg.toString(),
        statusCode: response.statusCode,
        code: errorCode,
      );
    }

    // Success envelope: { success: true, data: … }
    return data;
  }

  /// Attempt to refresh the access token.
  ///
  /// Returns `true` when a new token was obtained. Returns `false` ONLY when the
  /// refresh token is genuinely invalid (no stored token, or the refresh
  /// endpoint answers 401/403) — that is the only case in which the caller
  /// should force a logout. On a transient failure (timeout, connectivity loss,
  /// 5xx) it THROWS so the caller propagates the error and keeps the session,
  /// instead of logging the user out over a momentary blip.
  Future<bool> _tryRefresh() async {
    // Web carries the refresh token in an HttpOnly cookie the browser attaches
    // automatically, so there is no in-memory token to gate on. Native must
    // have a stored refresh token to send in the body.
    if (!kUsesHttpOnlyRefreshCookie && _refreshToken == null) return false;

    http.Response response;
    try {
      final uri = Uri.parse('$baseUrl/auth/refresh');
      response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          kUsesHttpOnlyRefreshCookie
              ? <String, dynamic>{}
              : {'refreshToken': _refreshToken},
        ),
      ).timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'La requête a expiré — réessayez',
        code: 'REQUEST_TIMEOUT',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      // Network error while refreshing — do NOT purge tokens; surface it so the
      // session survives the blip.
      throw const ApiException('Erreur réseau — vérifiez votre connexion');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final tokenData = body['data'];
        if (tokenData is Map<String, dynamic>) {
          await _persistTokens(
            tokenData['accessToken'] as String?,
            tokenData['refreshToken'] as String?,
          );
          return true;
        }
      } catch (_) {/* malformed success → treat as a failed refresh */}
      return false;
    }

    // The refresh token itself is rejected → a real, non-recoverable logout.
    if (response.statusCode == 401 || response.statusCode == 403) {
      return false;
    }

    // Any other status (5xx, etc.) is transient — keep the session.
    throw const ApiException('Erreur réseau — vérifiez votre connexion');
  }

  // ---------------------------------------------------------------------------
  // Auth convenience methods
  // ---------------------------------------------------------------------------

  /// Cast a decoded JSON field to a Map, throwing a typed [ApiException] rather
  /// than an uncatchable TypeError when the server returns an unexpected shape.
  Map<String, dynamic> _requireMap(Object? value, String field) {
    if (value is Map<String, dynamic>) return value;
    throw ApiException(
      'Réponse inattendue du serveur (champ "$field" manquant ou invalide)',
      code: 'MALFORMED_RESPONSE',
    );
  }

  /// POST /auth/login → stores tokens, returns user map.
  Future<UserItem> login(String email, String password) async {
    final result = await post('/auth/login', {
      'email': email,
      'password': password,
    });

    final data = _requireMap(result['data'], 'data');
    final tokens = _requireMap(data['tokens'], 'tokens');
    await _persistTokens(
      tokens['accessToken'] as String?,
      tokens['refreshToken'] as String?,
    );
    return UserItem.fromJson(_requireMap(data['user'], 'user'));
  }

  /// POST /auth/register → stores tokens, returns user map.
  Future<UserItem> register(
    String firstName,
    String lastName,
    String email,
    String password, {
    String? role,
  }) async {
    final body = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
    };
    if (role != null) body['role'] = role;

    final result = await post('/auth/register', body);

    final data = _requireMap(result['data'], 'data');
    final tokens = _requireMap(data['tokens'], 'tokens');
    await _persistTokens(
      tokens['accessToken'] as String?,
      tokens['refreshToken'] as String?,
    );
    return UserItem.fromJson(_requireMap(data['user'], 'user'));
  }

  /// POST /auth/logout → clears local tokens.
  Future<void> logout() async {
    try {
      await post('/auth/logout', null);
    } catch (_) {
      // Best-effort – always clear local tokens regardless of server response.
    }
    await _clearTokens();
  }

  /// GET /auth/profile → returns user map.
  Future<UserItem> getProfile() async {
    final result = await get('/auth/profile');
    return UserItem.fromJson(_requireMap(result['data'], 'data'));
  }

  // ---------------------------------------------------------------------------
  // Theme persistence
  // ---------------------------------------------------------------------------

  static const _themeModeKey = 'theme_mode';

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(_themeModeKey, value);
  }
}
