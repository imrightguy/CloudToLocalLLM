import 'package:web/web.dart' as web;
import 'auth_web_utils.dart';

class AuthWebUtilsWeb implements AuthWebUtils {
  @override
  String? get currentUrl => web.window.location.href;

  @override
  String? get origin => web.window.location.origin;

  @override
  String? getLocalStorageItem(String key) =>
      web.window.localStorage.getItem(key);

  @override
  void setLocalStorageItem(String key, String value) =>
      web.window.localStorage.setItem(key, value);

  @override
  void removeLocalStorageItem(String key) =>
      web.window.localStorage.removeItem(key);
}

AuthWebUtils getAuthWebUtils() => AuthWebUtilsWeb();
