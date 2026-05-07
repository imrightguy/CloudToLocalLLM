// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:shared_preferences/shared_preferences.dart';

class AuthTokens {
  const AuthTokens({this.accessToken, this.refreshToken});

  final String? accessToken;
  final String? refreshToken;
}

const _accessTokenKey = 'access_token';
const _refreshTokenKey = 'refresh_token';
const _flutterAccessTokenKey = 'flutter.access_token';
const _flutterRefreshTokenKey = 'flutter.refresh_token';

String? _readLocalStorageValue(String key) {
  return html.window.localStorage[key] ??
      html.window.localStorage['flutter.$key'];
}

Future<AuthTokens> readAuthTokens() async {
  final prefs = await SharedPreferences.getInstance();
  final accessToken = prefs.getString(_accessTokenKey) ??
      _readLocalStorageValue(_accessTokenKey) ??
      _readLocalStorageValue(_flutterAccessTokenKey);
  final refreshToken = prefs.getString(_refreshTokenKey) ??
      _readLocalStorageValue(_refreshTokenKey) ??
      _readLocalStorageValue(_flutterRefreshTokenKey);

  return AuthTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
  );
}

Future<void> writeAuthTokens({
  String? accessToken,
  String? refreshToken,
}) async {
  final prefs = await SharedPreferences.getInstance();

  if (accessToken != null) {
    await prefs.setString(_accessTokenKey, accessToken);
    html.window.localStorage[_accessTokenKey] = accessToken;
    html.window.localStorage[_flutterAccessTokenKey] = accessToken;
  }
  if (refreshToken != null) {
    await prefs.setString(_refreshTokenKey, refreshToken);
    html.window.localStorage[_refreshTokenKey] = refreshToken;
    html.window.localStorage[_flutterRefreshTokenKey] = refreshToken;
  }
}

Future<void> clearAuthTokens() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_accessTokenKey);
  await prefs.remove(_refreshTokenKey);
  html.window.localStorage.remove(_accessTokenKey);
  html.window.localStorage.remove(_refreshTokenKey);
  html.window.localStorage.remove(_flutterAccessTokenKey);
  html.window.localStorage.remove(_flutterRefreshTokenKey);
}
