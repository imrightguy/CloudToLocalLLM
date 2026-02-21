import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import '../test_config.dart';

void main() {
  group('Settings Integration Tests', () {
    late SettingsPreferenceService settingsService;

    setUp(() async {
      TestConfig.initialize();
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsPreferenceService();
    });

    tearDown(() async {
      TestConfig.cleanup();
    });

    group('End-to-End Settings Flow', () {
      test('should load and save theme preference', () async {
        // Initial state
        var theme = await settingsService.getTheme();
        expect(theme, 'system');

        // Save new theme
        await settingsService.setTheme('dark');
        theme = await settingsService.getTheme();
        expect(theme, 'dark');

        // Verify persistence
        await settingsService.setTheme('light');
        theme = await settingsService.getTheme();
        expect(theme, 'light');
      });

      test('should load and save language preference', () async {
        // Initial state
        var language = await settingsService.getLanguage();
        expect(language, 'en');

        // Save new language
        await settingsService.setLanguage('es');
        language = await settingsService.getLanguage();
        expect(language, 'es');

        // Verify persistence
        await settingsService.setLanguage('fr');
        language = await settingsService.getLanguage();
        expect(language, 'fr');
      });

      test('should manage privacy settings', () async {
        // Test analytics
        var analyticsEnabled = await settingsService.isAnalyticsEnabled();
        expect(analyticsEnabled, true);

        await settingsService.setAnalyticsEnabled(false);
        analyticsEnabled = await settingsService.isAnalyticsEnabled();
        expect(analyticsEnabled, false);

        // Test crash reporting
        var crashReportingEnabled =
            await settingsService.isCrashReportingEnabled();
        expect(crashReportingEnabled, true);

        await settingsService.setCrashReportingEnabled(false);
        crashReportingEnabled = await settingsService.isCrashReportingEnabled();
        expect(crashReportingEnabled, false);

        // Test usage stats
        var usageStatsEnabled = await settingsService.isUsageStatsEnabled();
        expect(usageStatsEnabled, true);

        await settingsService.setUsageStatsEnabled(false);
        usageStatsEnabled = await settingsService.isUsageStatsEnabled();
        expect(usageStatsEnabled, false);
      });

      test('should manage desktop settings', () async {
        // Test launch on startup
        var launchOnStartup = await settingsService.isLaunchOnStartupEnabled();
        expect(launchOnStartup, false);

        await settingsService.setLaunchOnStartupEnabled(true);
        launchOnStartup = await settingsService.isLaunchOnStartupEnabled();
        expect(launchOnStartup, true);

        // Test minimize to tray
        var minimizeToTray = await settingsService.isMinimizeToTrayEnabled();
        expect(minimizeToTray, false);

        await settingsService.setMinimizeToTrayEnabled(true);
        minimizeToTray = await settingsService.isMinimizeToTrayEnabled();
        expect(minimizeToTray, true);

        // Test always on top
        var alwaysOnTop = await settingsService.isAlwaysOnTopEnabled();
        expect(alwaysOnTop, false);

        await settingsService.setAlwaysOnTopEnabled(true);
        alwaysOnTop = await settingsService.isAlwaysOnTopEnabled();
        expect(alwaysOnTop, true);
      });

      test('should manage window position and size', () async {
        // Test window position
        var position = await settingsService.getWindowPosition();
        expect(position['x'], 0.0);
        expect(position['y'], 0.0);

        await settingsService.setWindowPosition(100.0, 200.0);
        position = await settingsService.getWindowPosition();
        expect(position['x'], 100.0);
        expect(position['y'], 200.0);

        // Test window size
        var size = await settingsService.getWindowSize();
        expect(size['width'], 1280.0);
        expect(size['height'], 720.0);

        await settingsService.setWindowSize(1920.0, 1080.0);
        size = await settingsService.getWindowSize();
        expect(size['width'], 1920.0);
        expect(size['height'], 1080.0);
      });

      test('should manage mobile settings', () async {
        // Test biometric auth
        var biometricAuth = await settingsService.isBiometricAuthEnabled();
        expect(biometricAuth, false);

        await settingsService.setBiometricAuthEnabled(true);
        biometricAuth = await settingsService.isBiometricAuthEnabled();
        expect(biometricAuth, true);

        // Test notifications
        var notificationsEnabled =
            await settingsService.isNotificationsEnabled();
        expect(notificationsEnabled, true);

        await settingsService.setNotificationsEnabled(false);
        notificationsEnabled = await settingsService.isNotificationsEnabled();
        expect(notificationsEnabled, false);

        // Test notification sound
        var notificationSound =
            await settingsService.isNotificationSoundEnabled();
        expect(notificationSound, true);

        await settingsService.setNotificationSoundEnabled(false);
        notificationSound = await settingsService.isNotificationSoundEnabled();
        expect(notificationSound, false);

        // Test vibration
        var vibrationEnabled = await settingsService.isVibrationEnabled();
        expect(vibrationEnabled, true);

        await settingsService.setVibrationEnabled(false);
        vibrationEnabled = await settingsService.isVibrationEnabled();
        expect(vibrationEnabled, false);
      });

      test('should clear all data', () async {
        // Set various preferences
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');
        await settingsService.setAnalyticsEnabled(false);
        await settingsService.setLaunchOnStartupEnabled(true);

        // Verify they are set
        expect(await settingsService.getTheme(), 'dark');
        expect(await settingsService.getLanguage(), 'es');
        expect(await settingsService.isAnalyticsEnabled(), false);
        expect(await settingsService.isLaunchOnStartupEnabled(), true);

        // Clear all data
        await settingsService.clearAllData();

        // Verify defaults are restored
        expect(await settingsService.getTheme(), 'system');
        expect(await settingsService.getLanguage(), 'en');
        expect(await settingsService.isAnalyticsEnabled(), true);
        expect(await settingsService.isLaunchOnStartupEnabled(), false);
      });
    });

    group('Settings Persistence Across Restarts', () {
      test('should persist theme preference across service restarts', () async {
        // Set theme
        await settingsService.setTheme('dark');
        expect(await settingsService.getTheme(), 'dark');

        // Simulate service restart by creating new instance
        final newService = SettingsPreferenceService();
        expect(await newService.getTheme(), 'dark');
      });

      test('should persist multiple settings across restarts', () async {
        // Set multiple preferences
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');
        await settingsService.setAnalyticsEnabled(false);
        await settingsService.setLaunchOnStartupEnabled(true);
        await settingsService.setWindowPosition(100.0, 200.0);

        // Simulate service restart
        final newService = SettingsPreferenceService();

        // Verify all settings persisted
        expect(await newService.getTheme(), 'dark');
        expect(await newService.getLanguage(), 'es');
        expect(await newService.isAnalyticsEnabled(), false);
        expect(await newService.isLaunchOnStartupEnabled(), true);

        final position = await newService.getWindowPosition();
        expect(position['x'], 100.0);
        expect(position['y'], 200.0);
      });

      test('should handle partial settings persistence', () async {
        // Set only some preferences
        await settingsService.setTheme('light');
        // Don't set language, analytics, etc.

        // Simulate service restart
        final newService = SettingsPreferenceService();

        // Verify set preference persisted
        expect(await newService.getTheme(), 'light');

        // Verify unset preferences have defaults
        expect(await newService.getLanguage(), 'en');
        expect(await newService.isAnalyticsEnabled(), true);
      });
    });

    group('Platform-Specific Settings', () {
      test('should handle desktop settings on desktop platform', () async {
        // These should work regardless of platform
        await settingsService.setLaunchOnStartupEnabled(true);
        await settingsService.setMinimizeToTrayEnabled(true);
        await settingsService.setAlwaysOnTopEnabled(true);

        expect(await settingsService.isLaunchOnStartupEnabled(), true);
        expect(await settingsService.isMinimizeToTrayEnabled(), true);
        expect(await settingsService.isAlwaysOnTopEnabled(), true);
      });

      test('should handle mobile settings on mobile platform', () async {
        // These should work regardless of platform
        await settingsService.setBiometricAuthEnabled(true);
        await settingsService.setNotificationsEnabled(false);
        await settingsService.setNotificationSoundEnabled(false);
        await settingsService.setVibrationEnabled(false);

        expect(await settingsService.isBiometricAuthEnabled(), true);
        expect(await settingsService.isNotificationsEnabled(), false);
        expect(await settingsService.isNotificationSoundEnabled(), false);
        expect(await settingsService.isVibrationEnabled(), false);
      });
    });

    group('Settings Validation', () {
      test('should reject invalid theme values', () {
        expect(
          () => settingsService.setTheme('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should reject invalid language values', () {
        expect(
          () => settingsService.setLanguage('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should accept valid theme values', () async {
        for (final theme in ['light', 'dark', 'system']) {
          await settingsService.setTheme(theme);
          expect(await settingsService.getTheme(), theme);
        }
      });

      test('should accept valid language values', () async {
        for (final language in ['en', 'es', 'fr', 'de', 'ja', 'zh']) {
          await settingsService.setLanguage(language);
          expect(await settingsService.getLanguage(), language);
        }
      });
    });

    group('Concurrent Settings Operations', () {
      test('should handle concurrent setting updates', () async {
        final futures = [
          settingsService.setTheme('dark'),
          settingsService.setLanguage('es'),
          settingsService.setAnalyticsEnabled(false),
          settingsService.setLaunchOnStartupEnabled(true),
          settingsService.setWindowPosition(100.0, 200.0),
        ];

        await Future.wait(futures);

        // Verify all settings were applied
        expect(await settingsService.getTheme(), 'dark');
        expect(await settingsService.getLanguage(), 'es');
        expect(await settingsService.isAnalyticsEnabled(), false);
        expect(await settingsService.isLaunchOnStartupEnabled(), true);

        final position = await settingsService.getWindowPosition();
        expect(position['x'], 100.0);
        expect(position['y'], 200.0);
      });

      test('should handle concurrent reads', () async {
        // Set initial values
        await settingsService.setTheme('dark');
        await settingsService.setLanguage('es');

        // Perform concurrent reads
        final futures = [
          settingsService.getTheme(),
          settingsService.getLanguage(),
          settingsService.isAnalyticsEnabled(),
          settingsService.getWindowPosition(),
        ];

        final results = await Future.wait(futures);

        expect(results[0], 'dark');
        expect(results[1], 'es');
        expect(results[2], true);
        expect(results[3], isA<Map<String, double>>());
      });
    });

    group('Error Handling', () {
      test('should handle SharedPreferences errors gracefully', () async {
        // This test verifies that the service handles potential errors
        // The actual error handling depends on SharedPreferences implementation
        try {
          await settingsService.getTheme();
          expect(true, true); // Should not throw
        } catch (e) {
          fail('Should not throw: $e');
        }
      });

      test('should maintain consistency after failed operations', () async {
        // Set initial value
        await settingsService.setTheme('dark');
        expect(await settingsService.getTheme(), 'dark');

        // Try invalid operation
        try {
          await settingsService.setTheme('invalid');
        } catch (e) {
          // Expected to fail
        }

        // Verify previous value is still intact
        expect(await settingsService.getTheme(), 'dark');
      });
    });
  });
}
