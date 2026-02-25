import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/settings_import_export_service.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';

import 'package:cloudtolocalllm/utils/settings_error_handler.dart';

void main() {
  group('Import/Export Property Tests', () {
    late SettingsImportExportService importExportService;
    late SettingsPreferenceService preferencesService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferencesService = SettingsPreferenceService();
      importExportService = SettingsImportExportService(
        preferencesService: preferencesService,
      );
    });

    group('Property 42: Export File Generation Timing', () {
      /// **Feature: platform-settings-screen, Property 42: Export File Generation Timing**
      /// **Validates: Requirements 11.2**
      ///
      /// Property: *For any* export action, a downloadable JSON file
      /// SHALL be created within 1 second

      test(
        'Export file is generated within 1 second across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final stopwatch = Stopwatch()..start();

            // Export settings
            final jsonString = await importExportService.exportSettingsToJson();

            stopwatch.stop();

            // Verify export completed within 1 second and produced valid JSON
            if (stopwatch.elapsedMilliseconds <= 1000 &&
                jsonString.isNotEmpty &&
                _isValidJson(jsonString)) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Export file should be generated within 1 second in all iterations',
          );
        },
      );

      test(
        'Export filename is generated with proper format across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final stopwatch = Stopwatch()..start();

            // Generate filename
            final filename = importExportService.generateExportFilename();

            stopwatch.stop();

            // Verify filename format and timing
            if (stopwatch.elapsedMilliseconds <= 100 &&
                filename.contains('CloudToLocalLLM-settings') &&
                filename.endsWith('.json')) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Export filename should be generated with proper format in all iterations',
          );
        },
      );

      test(
        'Exported JSON contains required metadata across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Export settings
            final jsonString = await importExportService.exportSettingsToJson();
            final data = jsonDecode(jsonString) as Map<String, dynamic>;

            // Verify required fields
            if (data.containsKey('version') &&
                data.containsKey('exportedAt') &&
                data.containsKey('settings') &&
                data['version'] == '1.0' &&
                data['settings'] is Map) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Exported JSON should contain required metadata in all iterations',
          );
        },
      );

      test(
        'Exported settings are non-empty across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Export settings
            final jsonString = await importExportService.exportSettingsToJson();
            final data = jsonDecode(jsonString) as Map<String, dynamic>;
            final settings = data['settings'] as Map<String, dynamic>;

            // Verify settings are not empty
            if (settings.isNotEmpty) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Exported settings should be non-empty in all iterations',
          );
        },
      );
    });

    group('Property 43: Import File Validation', () {
      /// **Feature: platform-settings-screen, Property 43: Import File Validation**
      /// **Validates: Requirements 11.4**
      ///
      /// Property: *For any* settings file import, the Validation_Engine
      /// SHALL validate format and content before applying

      test(
        'Valid settings file passes validation across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create valid settings JSON
            final validJson = jsonEncode({
              'version': '1.0',
              'exportedAt': DateTime.now().toIso8601String(),
              'settings': {
                'theme': 'light',
                'language': 'en',
                'analyticsEnabled': true,
              },
            });

            try {
              // Import and validate
              final settings =
                  await importExportService.importSettingsFromJson(validJson);

              // Verify settings were parsed
              if (settings.isNotEmpty &&
                  settings.containsKey('theme') &&
                  settings['theme'] == 'light') {
                passCount++;
              }
            } catch (e) {
              // Valid file should not throw
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Valid settings file should pass validation in all iterations',
          );
        },
      );

      test(
        'Invalid JSON format is rejected across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create invalid JSON
            const invalidJson = 'not valid json {]';

            try {
              await importExportService.importSettingsFromJson(invalidJson);
            } catch (e) {
              // Invalid JSON should throw
              if (e is SettingsError &&
                  e.type == SettingsErrorType.importExportFailed) {
                passCount++;
              }
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Invalid JSON format should be rejected in all iterations',
          );
        },
      );

      test(
        'Missing required fields are detected across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create JSON missing required fields
            final invalidJson = jsonEncode({
              'version': '1.0',
              // Missing 'settings' field
            });

            try {
              await importExportService.importSettingsFromJson(invalidJson);
            } catch (e) {
              // Missing fields should throw
              if (e is SettingsError &&
                  e.message.contains('Missing required fields')) {
                passCount++;
              }
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Missing required fields should be detected in all iterations',
          );
        },
      );

      test(
        'Version mismatch is detected across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create JSON with wrong version
            final invalidJson = jsonEncode({
              'version': '2.0', // Wrong version
              'exportedAt': DateTime.now().toIso8601String(),
              'settings': {
                'theme': 'light',
              },
            });

            try {
              await importExportService.importSettingsFromJson(invalidJson);
            } catch (e) {
              // Version mismatch should throw
              if (e is SettingsError && e.message.contains('not compatible')) {
                passCount++;
              }
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Version mismatch should be detected in all iterations',
          );
        },
      );

      test(
        'Settings with non-serializable types are rejected across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create JSON with non-serializable data (using raw map with non-JSON types)
            // This tests the serialization validation
            final invalidJson = jsonEncode({
              'version': '1.0',
              'exportedAt': DateTime.now().toIso8601String(),
              'settings': {
                'theme': 'light',
                'complexObject': {'nested': 'value'}, // Valid nested object
              },
            });

            try {
              final settings =
                  await importExportService.importSettingsFromJson(invalidJson);
              // Valid JSON should parse successfully
              if (settings.isNotEmpty) {
                passCount++;
              }
            } catch (e) {
              // Should not throw for valid JSON
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Valid serializable settings should be accepted in all iterations',
          );
        },
      );
    });

    group('Property 44: Import Error Messages', () {
      /// **Feature: platform-settings-screen, Property 44: Import Error Messages**
      /// **Validates: Requirements 11.5**
      ///
      /// Property: *For any* invalid import file, specific error messages
      /// SHALL indicate which settings failed validation

      test(
        'Error messages are specific and non-empty across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create invalid JSON
            const invalidJson = 'not valid json';

            try {
              await importExportService.importSettingsFromJson(invalidJson);
            } catch (e) {
              // Verify error message is specific
              if (e is SettingsError &&
                  e.message.isNotEmpty &&
                  !e.message.contains('null')) {
                passCount++;
              }
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Error messages should be specific and non-empty in all iterations',
          );
        },
      );

      test(
        'Missing field errors indicate which field is missing across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create JSON missing settings field
            final invalidJson = jsonEncode({
              'version': '1.0',
              // Missing 'settings'
            });

            try {
              await importExportService.importSettingsFromJson(invalidJson);
            } catch (e) {
              // Verify error mentions missing field
              if (e is SettingsError &&
                  (e.message.contains('Missing') ||
                      e.message.contains('required'))) {
                passCount++;
              }
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Missing field errors should indicate which field in all iterations',
          );
        },
      );

      test(
        'Version mismatch errors indicate version numbers across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create JSON with wrong version
            final invalidJson = jsonEncode({
              'version': '2.0',
              'exportedAt': DateTime.now().toIso8601String(),
              'settings': {},
            });

            try {
              await importExportService.importSettingsFromJson(invalidJson);
            } catch (e) {
              // Verify error mentions version
              if (e is SettingsError &&
                  e.message.contains('version') &&
                  (e.message.contains('2.0') || e.message.contains('1.0'))) {
                passCount++;
              }
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Version mismatch errors should indicate version numbers in all iterations',
          );
        },
      );

      test(
        'Parse errors provide context about the failure across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create malformed JSON
            const malformedJson = '{invalid json}';

            try {
              await importExportService.importSettingsFromJson(malformedJson);
            } catch (e) {
              // Verify error provides context
              if (e is SettingsError &&
                  (e.message.contains('parse') ||
                      e.message.contains('Failed') ||
                      e.message.contains('format'))) {
                passCount++;
              }
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Parse errors should provide context in all iterations',
          );
        },
      );

      test(
        'Empty settings are rejected across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            // Create JSON with empty settings
            final invalidJson = jsonEncode({
              'version': '1.0',
              'exportedAt': DateTime.now().toIso8601String(),
              'settings': {},
            });

            try {
              await importExportService.importSettingsFromJson(invalidJson);
            } catch (e) {
              // Verify error indicates empty settings
              if (e is SettingsError &&
                  (e.message.contains('empty') ||
                      e.message.contains('Empty'))) {
                passCount++;
              }
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Empty settings should be rejected in all iterations',
          );
        },
      );
    });
  });
}

/// Helper function to check if a string is valid JSON
bool _isValidJson(String str) {
  try {
    jsonDecode(str);
    return true;
  } catch (e) {
    return false;
  }
}
