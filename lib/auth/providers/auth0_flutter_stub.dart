import 'package:auth0_flutter/auth0_flutter.dart';

enum CacheLocation {
  localStorage,
  memory,
}

class Auth0Web {
  Auth0Web(String domain, String clientId, {String? redirectUrl});

  Future<Credentials?> onLoad({
    String? audience,
    Set<String>? scopes,
    bool? useRefreshTokens,
    CacheLocation? cacheLocation,
  }) async =>
      null;

  Future<void> loginWithRedirect({
    String? audience,
    Set<String>? scopes,
    String? redirectUrl,
  }) async {}

  Future<void> logout({String? returnToUrl}) async {}

  Future<Credentials> credentials() async => throw UnimplementedError();
}
