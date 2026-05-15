enum AppEnvironment { development, demo, staging, production }

class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  static const String _envString = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const bool demoModeEnabled = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );

  static const String _demoDataSourceValue = String.fromEnvironment(
    'DEMO_DATA_SOURCE',
    defaultValue: 'api',
  );

  static const String demoCompanyId = '388be569-9d9d-46e2-b548-7bf0167cb11b';

  static AppEnvironment get environment {
    switch (_envString) {
      case 'demo':
        return AppEnvironment.demo;
      case 'staging':
        return AppEnvironment.staging;
      case 'production':
        return AppEnvironment.production;
      default:
        return AppEnvironment.development;
    }
  }

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isDemo =>
      environment == AppEnvironment.demo || demoModeEnabled;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isDevelopment => environment == AppEnvironment.development;

  static String get demoDataSource => _demoDataSourceValue.trim().toLowerCase();

  static bool get usesInternalDemoData =>
      demoModeEnabled && demoDataSource == 'internal';

  static bool get usesLiveApi => !usesInternalDemoData;

  static String get activeDemoProfile {
    if (usesInternalDemoData) {
      return 'internal';
    }

    if (demoModeEnabled) {
      return 'api';
    }

    return 'none';
  }
}
