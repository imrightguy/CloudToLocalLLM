import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models.dart';

/// Custom exception for API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
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

  // SharedPreferences keys
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  String? _accessToken;
  String? _refreshToken;

  /// Whether tokens have been loaded from storage.
  bool _initialized = false;

  /// Initialise – load persisted tokens from [SharedPreferences].
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Token helpers
  // ---------------------------------------------------------------------------

  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  Map<String, String> _getHeaders() => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<void> _persistTokens(String? access, String? refresh) async {
    final prefs = await SharedPreferences.getInstance();
    if (access != null) {
      _accessToken = access;
      await prefs.setString(_accessTokenKey, access);
    }
    if (refresh != null) {
      _refreshToken = refresh;
      await prefs.setString(_refreshTokenKey, refresh);
    }
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
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
          response = await http.get(uri, headers: _getHeaders());
          break;
        case 'POST':
          response = await http.post(uri,
              headers: _getHeaders(), body: jsonEncode(body));
          break;
        case 'PUT':
          response = await http.put(uri,
              headers: _getHeaders(), body: jsonEncode(body));
          break;
        case 'PATCH':
          response = await http.patch(uri,
              headers: _getHeaders(), body: jsonEncode(body));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: _getHeaders());
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
      final errorMsg = data['error'] is Map
          ? data['error']['message'] ?? data['error'].toString()
          : data['message'] ?? 'Erreur ${response.statusCode}';
      throw ApiException(errorMsg.toString(), statusCode: response.statusCode);
    }

    // Success envelope: { success: true, data: … }
    return data;
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
}
