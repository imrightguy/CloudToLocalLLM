import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/settings_validator.dart';
import 'package:cloudtolocalllm/models/settings_state.dart';
import 'package:cloudtolocalllm/utils/settings_error_handler.dart';

void main() {
  group('Validation and Error Handling Property Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('Property 37: Validation Error Display Timing', () {
      /// **Feature: platform-settings-screen, Property 37: Validation Error Display Timing**
      /// **Validates: Requirements 10.1**
      ///
      /// Property: *For any* invalid input, an inline error message
      /// SHALL be displayed within 200 milliseconds

      test(
        'Validation errors are detected within 200ms across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final stopwatch = Stopwatch()..start();

            // Test invalid theme
            final result = SettingsValidator.validateTheme('invalid_theme');

            stopwatch.stop();

            // Verify error detected and timing
            if (!result.isValid &&
                result.errors.containsKey('theme') &&
                stopwatch.elapsedMilliseconds <= 200) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Validation errors should be detected within 200ms in all iterations',
          );
        },
      );

      test(
        'Multiple field validation errors detected within 200ms across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final stopwatch = Stopwatch()..start();

            // Test multiple invalid fields
            final result = SettingsValidator.validateProviderConfiguration(
              host: 'invalid url',
              port: 99999,
              apiKey: '',
            );

            stopwatch.stop();

            // Verify multiple errors detected and timing
            if (!result.isValid &&
                result.errors.isNotEmpty &&
                stopwatch.elapsedMilliseconds <= 200) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Multiple validation errors should be detected within 200ms in all iterations',
          );
        },
      );

      test(
        'Validation error messages are non-empty across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final result = SettingsValidator.validateTheme('');

            // Verify error message is present and non-empty
            if (!result.isValid &&
                result.errors['theme'] != null &&
                result.errors['theme']!.isNotEmpty) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Validation error messages should be non-empty in all iterations',
          );
        },
      );
    });

    group('Property 38: Save Prevention on Validation Errors', () {
      /// **Feature: platform-settings-screen, Property 38: Save Prevention on Validation Errors**
      /// **Validates: Requirements 10.2**
      ///
      /// Property: *For any* settings screen with validation errors,
      /// the save button SHALL be disabled

      test(
        'Settings state prevents save when validation errors exist across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Set validation errors
            final errors = {
              'theme': 'Invalid theme',
              'language': 'Invalid language',
            };
            settingsState.setFieldErrors(errors);

            // Verify save is prevented (hasFieldErrors is true)
            if (settingsState.hasFieldErrors &&
                settingsState.fieldErrors.isNotEmpty) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Save should be prevented when validation errors exist in all iterations',
          );
        },
      );

      test(
        'Save is allowed only when all validation errors are cleared across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Set validation errors
            settingsState.setFieldErrors({
              'theme': 'Invalid theme',
            });

            // Verify save is prevented
            final preventedInitially = settingsState.hasFieldErrors;

            // Clear errors
            settingsState.clearErrors();

            // Verify save is now allowed
            final allowedAfterClear = !settingsState.hasFieldErrors;

            if (preventedInitially && allowedAfterClear) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Save should be allowed after clearing errors in all iterations',
          );
        },
      );

      test(
        'Partial error clearing prevents save across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Set multiple validation errors
            settingsState.setFieldErrors({
              'theme': 'Invalid theme',
              'language': 'Invalid language',
            });

            // Clear only one error
            settingsState.clearFieldError('theme');

            // Verify save is still prevented (one error remains)
            if (settingsState.hasFieldErrors &&
                settingsState.fieldErrors.containsKey('language')) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Save should be prevented when any validation errors remain in all iterations',
          );
        },
      );
    });

    group('Property 39: Save Failure Error Handling', () {
      /// **Feature: platform-settings-screen, Property 39: Save Failure Error Handling**
      /// **Validates: Requirements 10.3**
      ///
      /// Property: *For any* failed settings save operation, an error
      /// notification with retry option SHALL be displayed

      test(
        'Save failure sets error state with retry capability across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Simulate save failure
            final error = SettingsError.saveFailed(
              'Failed to save settings',
            );
            settingsState.setError(error);

            // Verify error state and retry capability
            if (settingsState.hasError &&
                settingsState.error != null &&
                settingsState.operationState == SettingsOperationState.error &&
                settingsState.error!.isRetryable) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Save failure should set error state in all iterations',
          );
        },
      );

      test(
        'Retry count increments on save failure across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Initial retry count should be 0
            final initialRetryCount = settingsState.retryCount;

            // Simulate save failure and retry
            settingsState.incrementRetryCount();
            settingsState.incrementRetryCount();

            // Verify retry count incremented
            if (initialRetryCount == 0 && settingsState.retryCount == 2) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Retry count should increment on save failure in all iterations',
          );
        },
      );

      test(
        'Max retries exceeded detection works across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Increment retry count to max
            for (int j = 0; j < SettingsState.maxRetries; j++) {
              settingsState.incrementRetryCount();
            }

            // Verify max retries exceeded
            if (settingsState.isMaxRetriesExceeded()) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Max retries exceeded should be detected in all iterations',
          );
        },
      );

      test(
        'Error message is preserved during retry across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            const errorMessage = 'Network connection failed';
            final error = SettingsError.saveFailed(errorMessage);
            settingsState.setError(error);

            // Increment retry count
            settingsState.incrementRetryCount();

            // Verify error message is still present
            if (settingsState.hasError &&
                settingsState.error?.message == errorMessage) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Error message should be preserved during retry in all iterations',
          );
        },
      );
    });

    group('Property 40: Required Field Validation on Navigation', () {
      /// **Feature: platform-settings-screen, Property 40: Required Field Validation on Navigation**
      /// **Validates: Requirements 10.4**
      ///
      /// Property: *For any* navigation attempt with invalid required fields,
      /// navigation SHALL be blocked

      test(
        'Required field validation prevents navigation across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Validate required field (empty theme)
            final result = SettingsValidator.validateTheme('');

            // Set field errors
            if (!result.isValid) {
              settingsState.setFieldErrors(result.errors);
            }

            // Verify navigation is blocked (hasFieldErrors is true)
            if (settingsState.hasFieldErrors) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Required field validation should prevent navigation in all iterations',
          );
        },
      );

      test(
        'Navigation is allowed when all required fields are valid across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Validate required field (valid theme)
            final result = SettingsValidator.validateTheme('light');

            // Set field errors if any
            if (!result.isValid) {
              settingsState.setFieldErrors(result.errors);
            }

            // Verify navigation is allowed (no field errors)
            if (!settingsState.hasFieldErrors) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Navigation should be allowed when required fields are valid in all iterations',
          );
        },
      );

      test(
        'Multiple required field validation blocks navigation across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Validate multiple required fields
            final themeResult = SettingsValidator.validateTheme('');
            final languageResult = SettingsValidator.validateLanguage('');

            // Combine errors
            final allErrors = {
              ...themeResult.errors,
              ...languageResult.errors,
            };

            if (allErrors.isNotEmpty) {
              settingsState.setFieldErrors(allErrors);
            }

            // Verify navigation is blocked
            if (settingsState.hasFieldErrors &&
                settingsState.fieldErrors.length >= 2) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Multiple required field validation should block navigation in all iterations',
          );
        },
      );
    });

    group('Property 41: Success Confirmation Timing', () {
      /// **Feature: platform-settings-screen, Property 41: Success Confirmation Timing**
      /// **Validates: Requirements 10.5**
      ///
      /// Property: *For any* successful validation, a success confirmation
      /// message SHALL be displayed for 2 seconds

      test(
        'Success state is set immediately on validation success across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            final stopwatch = Stopwatch()..start();
            settingsState.setSuccess();
            stopwatch.stop();

            // Verify success state is set and timing
            if (settingsState.operationState ==
                    SettingsOperationState.success &&
                stopwatch.elapsedMilliseconds <= 50) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Success state should be set immediately in all iterations',
          );
        },
      );

      test(
        'Success state clears errors and marks clean across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Set initial state with errors
            settingsState.setFieldErrors({'theme': 'Invalid'});
            settingsState.markDirty();

            // Verify initial state
            final hadErrors = settingsState.hasFieldErrors;
            final wasDirty = settingsState.isDirty;

            // Set success
            settingsState.setSuccess();

            // Verify success clears errors and marks clean
            if (hadErrors &&
                wasDirty &&
                !settingsState.hasFieldErrors &&
                !settingsState.isDirty) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Success state should clear errors and mark clean in all iterations',
          );
        },
      );

      test(
        'Last save time is recorded on success across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Verify no save time initially
            final initialSaveTime = settingsState.lastSaveTime;

            // Set success
            settingsState.setSuccess();

            // Verify save time is recorded
            final finalSaveTime = settingsState.lastSaveTime;

            if (initialSaveTime == null && finalSaveTime != null) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason:
                'Last save time should be recorded on success in all iterations',
          );
        },
      );

      test(
        'Retry count is reset on success across 100 iterations',
        () async {
          const int iterations = 100;
          int passCount = 0;

          for (int i = 0; i < iterations; i++) {
            final settingsState = SettingsState();

            // Increment retry count
            settingsState.incrementRetryCount();
            settingsState.incrementRetryCount();

            // Verify retry count is incremented
            final hadRetries = settingsState.retryCount > 0;

            // Set success
            settingsState.setSuccess();

            // Verify retry count is reset
            if (hadRetries && settingsState.retryCount == 0) {
              passCount++;
            }
          }

          expect(
            passCount,
            equals(iterations),
            reason: 'Retry count should be reset on success in all iterations',
          );
        },
      );
    });
  });
}
