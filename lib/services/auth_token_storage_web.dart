// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

class AuthTokens {
  const AuthTokens({this.accessToken, this.refreshToken});

  final String? accessToken;
  final String? refreshToken;
}

/// On web the refresh token is held by the backend in an HttpOnly cookie
/// (unreadable from JavaScript) and the access token lives only in memory.
/// Nothing auth-related is written to `localStorage`, which any injected
/// script could read — closing the XSS token-theft vector.
///
/// NOTE: The Dart `http` package does NOT automatically attach cookies to
/// requests. Until the HTTP client is migrated to one that supports
/// credentials (e.g. `package:fetch` or `dart:html` HttpRequest), the
/// refresh token is still sent in the request body on web. The cookie is
/// still set by the backend as defense-in-depth for future clients.
const bool kUsesHttpOnlyRefreshCookie = false;

/// Keys that older, XSS-exposed builds wrote to `localStorage`. We purge them
/// on load so previously-leaked tokens stop lingering in the browser.
const _legacyKeys = <String>[
  'access_token',
  'refresh_token',
  'flutter.access_token',
  'flutter.refresh_token',
];

void _purgeLegacyTokens() {
  for (final key in _legacyKeys) {
    html.window.localStorage.remove(key);
  }
}

Future<AuthTokens> readAuthTokens() async {
  // Nothing is persisted on web; also scrub any tokens left by older builds.
  _purgeLegacyTokens();
  return const AuthTokens();
}

Future<void> writeAuthTokens({
  String? accessToken,
  String? refreshToken,
}) async {
  // No-op on web: the access token stays in memory, the refresh token in the
  // HttpOnly cookie set by the backend.
}

Future<void> clearAuthTokens() async {
  _purgeLegacyTokens();
}
