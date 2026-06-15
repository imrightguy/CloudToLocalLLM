// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

class AuthTokens {
  const AuthTokens({this.accessToken, this.refreshToken});

  final String? accessToken;
  final String? refreshToken;
}

/// On web the access token lives only in memory (never persisted).
/// The refresh token is stored in `sessionStorage` — it survives a page
/// reload but is cleared when the tab closes. This is a pragmatic middle
/// ground: better than localStorage (XSS-readable forever) but still allows
/// the session to survive a hard refresh.
///
/// The backend also sets an HttpOnly cookie as defense-in-depth for future
/// clients that support `credentials: 'include'`.
const bool kUsesHttpOnlyRefreshCookie = false;

const _refreshTokenKey = 'rt';

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
  _purgeLegacyTokens();
  // Access token: memory only (never persisted on web).
  // Refresh token: sessionStorage (survives reload, cleared on tab close).
  final refreshToken = html.window.sessionStorage[_refreshTokenKey];
  return AuthTokens(refreshToken: refreshToken?.isNotEmpty == true ? refreshToken : null);
}

Future<void> writeAuthTokens({
  String? accessToken,
  String? refreshToken,
}) async {
  // Access token stays in memory only (ApiService._accessToken).
  // Refresh token goes to sessionStorage so the session survives a reload.
  if (refreshToken != null && refreshToken.isNotEmpty) {
    html.window.sessionStorage[_refreshTokenKey] = refreshToken;
  } else {
    html.window.sessionStorage.remove(_refreshTokenKey);
  }
}

Future<void> clearAuthTokens() async {
  _purgeLegacyTokens();
  html.window.sessionStorage.remove(_refreshTokenKey);
}
