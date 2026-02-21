import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';

void main() {
  group('General Settings - Theme Application Timing', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'Property 7: Theme Application Timing - Theme change applies within 200ms',
        () async {
      // **Feature: platform-settings-screen, Property 7: Theme Application Timing**
      // **Validates: Requirements 2.2**

      final themeProvider = ThemeProvider();

      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 100));

      // Measure time to apply theme change
      final stopwatch = Stopwatch()..start();

      // Change theme to dark
      await themeProvider.setThemeMode(ThemeMode.dark);

      stopwatch.stop();

      // Verify theme was changed
      expect(themeProvider.themeMode, equals(ThemeMode.dark));

      // Verify timing constraint: theme application should complete within 200ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(200),
        reason:
            'Theme application took ${stopwatch.elapsedMilliseconds}ms, should be < 200ms',
      );
    });

    test(
        'Property 7: Theme Application Timing - Multiple rapid theme changes apply within 200ms each',
        () async {
      // **Feature: platform-settings-screen, Property 7: Theme Application Timing**
      // **Validates: Requirements 2.2**

      final themeProvider = ThemeProvider();

      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 100));

      // Test multiple theme changes
      final themeModes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

      for (final themeMode in themeModes) {
        final stopwatch = Stopwatch()..start();

        await themeProvider.setThemeMode(themeMode);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(200),
          reason:
              'Theme change to $themeMode took ${stopwatch.elapsedMilliseconds}ms, should be < 200ms',
        );

        expect(themeProvider.themeMode, equals(themeMode));
      }
    });

    test(
        'Property 7: Theme Application Timing - Theme persists after application',
        () async {
      // **Feature: platform-settings-screen, Property 7: Theme Application Timing**
      // **Validates: Requirements 2.2**

      final themeProvider = ThemeProvider();

      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 100));

      // Apply theme change
      await themeProvider.setThemeMode(ThemeMode.dark);

      // Verify theme is applied
      expect(themeProvider.themeMode, equals(ThemeMode.dark));

      // Create a new ThemeProvider instance to verify persistence
      final newThemeProvider = ThemeProvider();

      // Wait for new instance to load
      await Future.delayed(const Duration(milliseconds: 100));

      // The new instance should load the saved theme
      expect(newThemeProvider.themeMode, equals(ThemeMode.dark));
    });
  });
}
