import 'package:shared_preferences/shared_preferences.dart';

class AuthTokens {
  const AuthTokens({this.accessToken, this.refreshToken});

  final String? accessToken;
  final String? refreshToken;
}

const _accessTokenKey = 'access_token';
const _refreshTokenKey = 'refresh_token';

Future<AuthTokens> readAuthTokens() async {
  final prefs = await SharedPreferences.getInstance();
  return AuthTokens(
    accessToken: prefs.getString(_accessTokenKey),
    refreshToken: prefs.getString(_refreshTokenKey),
  );
}

Future<void> writeAuthTokens({
  String? accessToken,
  String? refreshToken,
}) async {
  final prefs = await SharedPreferences.getInstance();

  if (accessToken != null) {
    await prefs.setString(_accessTokenKey, accessToken);
  }
  if (refreshToken != null) {
    await prefs.setString(_refreshTokenKey, refreshToken);
  }
}

Future<void> clearAuthTokens() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_accessTokenKey);
  await prefs.remove(_refreshTokenKey);
}
