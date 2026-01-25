import 'auth_web_utils.dart';

class AuthWebUtilsStub implements AuthWebUtils {
  @override
  String? get currentUrl => null;

  @override
  String? get origin => null;

  @override
  String? getLocalStorageItem(String key) => null;

  @override
  void setLocalStorageItem(String key, String value) {}

  @override
  void removeLocalStorageItem(String key) {}
}

AuthWebUtils getAuthWebUtils() => AuthWebUtilsStub();
