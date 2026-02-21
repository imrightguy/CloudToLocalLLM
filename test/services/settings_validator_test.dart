import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/settings_validator.dart';

void main() {
  group('SettingsValidator', () {
    group('validateTheme', () {
      test('returns success for valid theme light', () {
        final result = SettingsValidator.validateTheme('light');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns success for valid theme dark', () {
        final result = SettingsValidator.validateTheme('dark');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns success for valid theme system', () {
        final result = SettingsValidator.validateTheme('system');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for invalid theme', () {
        final result = SettingsValidator.validateTheme('invalid');
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
        expect(result.errors['theme'], contains('Invalid theme'));
      });

      test('returns error for null theme', () {
        final result = SettingsValidator.validateTheme(null);
        expect(result.isValid, false);
        expect(result.errors['theme'], contains('required'));
      });

      test('returns error for empty theme', () {
        final result = SettingsValidator.validateTheme('');
        expect(result.isValid, false);
        expect(result.errors['theme'], contains('required'));
      });
    });

    group('validateLanguage', () {
      test('returns success for valid language en', () {
        final result = SettingsValidator.validateLanguage('en');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns success for valid language es', () {
        final result = SettingsValidator.validateLanguage('es');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for invalid language', () {
        final result = SettingsValidator.validateLanguage('invalid');
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
        expect(result.errors['language'], contains('Invalid language'));
      });

      test('returns error for null language', () {
        final result = SettingsValidator.validateLanguage(null);
        expect(result.isValid, false);
        expect(result.errors['language'], contains('required'));
      });
    });

    group('validateProviderHost', () {
      test('returns success for valid URL', () {
        final result =
            SettingsValidator.validateProviderHost('http://localhost:11434');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns success for valid host without protocol', () {
        final result = SettingsValidator.validateProviderHost('localhost');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for null host', () {
        final result = SettingsValidator.validateProviderHost(null);
        expect(result.isValid, false);
        expect(result.errors['host'], contains('required'));
      });

      test('returns error for empty host', () {
        final result = SettingsValidator.validateProviderHost('');
        expect(result.isValid, false);
        expect(result.errors['host'], contains('required'));
      });
    });

    group('validateProviderPort', () {
      test('returns success for valid port number', () {
        final result = SettingsValidator.validateProviderPort(11434);
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns success for valid port string', () {
        final result = SettingsValidator.validateProviderPort('11434');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for port below minimum', () {
        final result = SettingsValidator.validateProviderPort(0);
        expect(result.isValid, false);
        expect(result.errors['port'], contains('between 1 and 65535'));
      });

      test('returns error for port above maximum', () {
        final result = SettingsValidator.validateProviderPort(65536);
        expect(result.isValid, false);
        expect(result.errors['port'], contains('between 1 and 65535'));
      });

      test('returns error for invalid port string', () {
        final result = SettingsValidator.validateProviderPort('invalid');
        expect(result.isValid, false);
        expect(result.errors['port'], contains('valid number'));
      });

      test('returns error for null port', () {
        final result = SettingsValidator.validateProviderPort(null);
        expect(result.isValid, false);
        expect(result.errors['port'], contains('required'));
      });
    });

    group('validateProviderApiKey', () {
      test('returns success for null API key', () {
        final result = SettingsValidator.validateProviderApiKey(null);
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns success for non-empty API key', () {
        final result =
            SettingsValidator.validateProviderApiKey('secret-key-123');
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for empty API key', () {
        final result = SettingsValidator.validateProviderApiKey('');
        expect(result.isValid, false);
        expect(result.errors['apiKey'], contains('cannot be empty'));
      });
    });

    group('validateProviderConfiguration', () {
      test('returns success for valid configuration', () {
        final result = SettingsValidator.validateProviderConfiguration(
          host: 'http://localhost:11434',
          port: 11434,
          apiKey: null,
        );
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for missing host', () {
        final result = SettingsValidator.validateProviderConfiguration(
          host: null,
          port: 11434,
          apiKey: null,
        );
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
      });

      test('returns error for invalid port', () {
        final result = SettingsValidator.validateProviderConfiguration(
          host: 'http://localhost',
          port: 99999,
          apiKey: null,
        );
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
      });

      test('returns multiple errors for multiple invalid fields', () {
        final result = SettingsValidator.validateProviderConfiguration(
          host: null,
          port: 99999,
          apiKey: '',
        );
        expect(result.isValid, false);
        expect(result.errors.length, greaterThan(1));
      });
    });

    group('validateWindowPosition', () {
      test('returns success for valid position', () {
        final result = SettingsValidator.validateWindowPosition(100, 200);
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for negative x', () {
        final result = SettingsValidator.validateWindowPosition(-100, 200);
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
      });

      test('returns error for negative y', () {
        final result = SettingsValidator.validateWindowPosition(100, -200);
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
      });

      test('returns error for null values', () {
        final result = SettingsValidator.validateWindowPosition(null, null);
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
      });
    });

    group('validateWindowSize', () {
      test('returns success for valid size', () {
        final result = SettingsValidator.validateWindowSize(1280, 720);
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for size below minimum', () {
        final result = SettingsValidator.validateWindowSize(300, 200);
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
      });

      test('returns error for size above maximum', () {
        final result = SettingsValidator.validateWindowSize(8000, 5000);
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
      });

      test('returns error for null values', () {
        final result = SettingsValidator.validateWindowSize(null, null);
        expect(result.isValid, false);
        expect(result.errors, isNotEmpty);
      });
    });

    group('validateSettingsJson', () {
      test('returns success for valid settings JSON', () {
        final json = {
          'theme': 'light',
          'language': 'en',
          'analytics': true,
        };
        final result = SettingsValidator.validateSettingsJson(json);
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns error for empty JSON', () {
        final result = SettingsValidator.validateSettingsJson({});
        expect(result.isValid, false);
        expect(result.overallError, contains('empty'));
      });

      test('returns success for nested JSON', () {
        final json = {
          'theme': 'light',
          'provider': {
            'host': 'localhost',
            'port': 11434,
          },
        };
        final result = SettingsValidator.validateSettingsJson(json);
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns success for JSON with arrays', () {
        final json = {
          'providers': [
            {'host': 'localhost', 'port': 11434},
            {'host': 'remote', 'port': 8000},
          ],
        };
        final result = SettingsValidator.validateSettingsJson(json);
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });
    });

    group('validateAllSettings', () {
      test('returns success when all settings are valid', () {
        final result = SettingsValidator.validateAllSettings(
          theme: 'light',
          language: 'en',
          providerHost: 'http://localhost',
          providerPort: 11434,
          windowWidth: 1280,
          windowHeight: 720,
        );
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns errors for multiple invalid settings', () {
        final result = SettingsValidator.validateAllSettings(
          theme: 'invalid',
          language: 'invalid',
          providerPort: 99999,
        );
        expect(result.isValid, false);
        expect(result.errors.length, greaterThan(1));
      });

      test('returns success when optional settings are null', () {
        final result = SettingsValidator.validateAllSettings(
          theme: 'light',
          language: 'en',
        );
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });
    });
  });

  group('ValidationResult', () {
    test('success result is valid', () {
      final result = ValidationResult.success();
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
      expect(result.overallError, isNull);
    });

    test('fieldErrors result is invalid', () {
      final errors = {'field1': 'error1', 'field2': 'error2'};
      final result = ValidationResult.fieldErrors(errors);
      expect(result.isValid, false);
      expect(result.errors, equals(errors));
    });

    test('error result is invalid', () {
      final result = ValidationResult.error('Something went wrong');
      expect(result.isValid, false);
      expect(result.overallError, equals('Something went wrong'));
    });

    test('getAllErrors returns all error messages', () {
      final errors = {'field1': 'error1', 'field2': 'error2'};
      final result = ValidationResult.fieldErrors(errors);
      final allErrors = result.getAllErrors();
      expect(allErrors.length, equals(2));
      expect(allErrors, contains('error1'));
      expect(allErrors, contains('error2'));
    });

    test('getAllErrors includes overall error', () {
      final result = ValidationResult.error('Overall error');
      final allErrors = result.getAllErrors();
      expect(allErrors.length, equals(1));
      expect(allErrors.first, equals('Overall error'));
    });
  });
}
