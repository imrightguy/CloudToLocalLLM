import '../app_config.dart';

class DemoMode {
  DemoMode._();

  static bool get isInternalDemoMode => AppConfig.usesInternalDemoData;

  static bool get usesLiveApi => AppConfig.usesLiveApi;

  static String get activeDemoProfile => AppConfig.activeDemoProfile;
}
