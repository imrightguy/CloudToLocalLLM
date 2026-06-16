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
    await writeAuthTokens(accessToken: access, refreshToken: refresh);
    _accessToken = access;
    _refreshToken = refresh;
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

  /// Like [get] but returns the full response envelope {success, data, metadata}
  /// instead of just data['data']. Use for paginated endpoints.
  Future<Map<String, dynamic>> getRaw(String path) async =>
      _request('GET', path, raw: true);

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
    bool raw = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await client.get(uri, headers: _getHeaders());
          break;
        case 'POST':
          response = await client.post(uri,
              headers: _getHeaders(), body: jsonEncode(body));
          break;
        case 'PUT':
          response = await client.put(uri,
              headers: _getHeaders(), body: jsonEncode(body));
          break;
        case 'PATCH':
          response = await client.patch(uri,
              headers: _getHeaders(), body: jsonEncode(body));
          break;
        case 'DELETE':
          response = await client.delete(uri, headers: _getHeaders());
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
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
    // When raw=true, return the full envelope; otherwise strip to data['data']
    return (raw ? data : (data['data'] ?? data)) as Map<String, dynamic>;
  }

  /// Attempt to refresh the access token. Returns `true` on success.
  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final uri = Uri.parse('$baseUrl/auth/refresh');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final tokenData = body['data'] as Map<String, dynamic>?;
        if (tokenData != null) {
          await _persistTokens(
            tokenData['accessToken'] as String?,
            tokenData['refreshToken'] as String?,
          );
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ---------------------------------------------------------------------------
  // Auth convenience methods
  // ---------------------------------------------------------------------------

  /// POST /auth/login → stores tokens, returns user map.
  Future<UserItem> login(String email, String password) async {
    final result = await post('/auth/login', {
      'email': email,
      'password': password,
    });

    final data = result['data'] as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>;
    await _persistTokens(
      tokens['accessToken'] as String?,
      tokens['refreshToken'] as String?,
    );
    return UserItem.fromJson(data['user'] as Map<String, dynamic>);
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

    final data = result['data'] as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>;
    await _persistTokens(
      tokens['accessToken'] as String?,
      tokens['refreshToken'] as String?,
    );
    return UserItem.fromJson(data['user'] as Map<String, dynamic>);
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
    return UserItem.fromJson(result['data'] as Map<String, dynamic>);
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
