import 'auth_web_utils_stub.dart'
    if (dart.library.js_interop) 'auth_web_utils_web.dart';

abstract class AuthWebUtils {
  String? get currentUrl;
  String? get origin;

  String? getLocalStorageItem(String key);
  void setLocalStorageItem(String key, String value);
  void removeLocalStorageItem(String key);
}

AuthWebUtils get authWebUtils => getAuthWebUtils();
