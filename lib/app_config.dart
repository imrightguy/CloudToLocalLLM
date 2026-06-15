class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '/api',
  );

  static const String companyId = '388be569-9d9d-46e2-b548-7bf0167cb11b';
}
