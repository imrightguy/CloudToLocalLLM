import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/app_config.dart';

void main() {
  group('AppConfig defaults', () {
    test('apiBaseUrl defaults to development emulator URL', () {
      expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:3000/api');
    });

    test('environment defaults to development', () {
      expect(AppConfig.environment, AppEnvironment.development);
    });

    test('isDevelopment is true by default', () {
      expect(AppConfig.isDevelopment, isTrue);
      expect(AppConfig.isStaging, isFalse);
      expect(AppConfig.isProduction, isFalse);
    });
  });

  group('AppEnvironment', () {
    test('has three values', () {
      expect(AppEnvironment.values.length, 3);
      expect(AppEnvironment.values, containsAll([
        AppEnvironment.development,
        AppEnvironment.staging,
        AppEnvironment.production,
      ]));
    });
  });
}
