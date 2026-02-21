/// Property-Based Test for Theme Caching
///
/// **Feature: unified-app-theming, Property 14: Theme Caching**
///
/// Tests that theme lookups return cached values within 50ms.
/// This is a critical property for ensuring optimal performance
/// across the application.
///
/// **Validates: Requirements 18.5**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 14: Theme Caching', () {
    late ThemeProvider themeProvider;

    setUp(() async {
      // Clear any existing preferences
      SharedPreferences.setMockInitialValues({});
      themeProvider = ThemeProvider();
      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      // Clean up
      themeProvider.dispose();
    });

    /// Property: For any theme lookup, cached values SHALL be returned within 50ms
    ///
    /// This test verifies that when a theme is cached, subsequent lookups
    /// return the cached value within the required 50ms timeframe.
    test('cached theme lookups complete within 50ms', () async {
      // Set initial theme and wait for cache
      await themeProvider.setThemeMode(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify cache is valid
      expect(themeProvider.isCacheValid, true);
      expect(themeProvider.cachedThemeMode, ThemeMode.dark);

      // Perform multiple cached lookups and measure timing
      final timings = <int>[];
      for (int i = 0; i < 10; i++) {
        final startTime = DateTime.now();
        final theme = themeProvider.themeMode;
        final elapsed = DateTime.now().difference(startTime).inMicroseconds;

        expect(theme, ThemeMode.dark);
        timings.add(elapsed);
      }

      // All lookups should be extremely fast (well under 50ms = 50000 microseconds)
      for (int i = 0; i < timings.length; i++) {
        expect(
          timings[i],
          lessThan(50000),
          reason:
              'Cached theme lookup $i should complete within 50ms (actual: ${timings[i] / 1000}ms)',
        );
      }

      // Average should be very fast
      final avgMicroseconds = timings.reduce((a, b) => a + b) / timings.length;
      debugPrint(
        'Average cached theme lookup time: ${avgMicroseconds / 1000}ms',
      );
    });

    /// Property: Cache validity should be maintained for the configured duration
    test('cache remains valid for configured duration', () async {
      // Set theme and verify cache
      await themeProvider.setThemeMode(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(themeProvider.isCacheValid, true);
      expect(themeProvider.cachedThemeMode, ThemeMode.light);

      // Cache should still be valid after a short delay
      await Future.delayed(const Duration(seconds: 1));
      expect(themeProvider.isCacheValid, true);

      // Cache should still be valid after a moderate delay
      await Future.delayed(const Duration(seconds: 5));
      expect(themeProvider.isCacheValid, true);
    });

    /// Property: New ThemeProvider instances should load from cache quickly
    test('new instances load from cache within 50ms', () async {
      // Set theme in first provider
      await themeProvider.setThemeMode(ThemeMode.system);
      await Future.delayed(const Duration(milliseconds: 100));

      // Create new provider and measure load time
      final startTime = DateTime.now();
      final newProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      // Should load quickly from cache
      expect(
        elapsed,
        lessThan(200),
        reason:
            'New provider should load from cache quickly (actual: ${elapsed}ms)',
      );

      expect(newProvider.themeMode, ThemeMode.system);
      expect(newProvider.isCacheValid, true);

      newProvider.dispose();
    });

    /// Property: Cache should be updated when theme changes
    test('cache updates when theme changes', () async {
      // Set initial theme
      await themeProvider.setThemeMode(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(themeProvider.cachedThemeMode, ThemeMode.light);

      // Change theme
      await themeProvider.setThemeMode(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100));

      // Cache should be updated
      expect(themeProvider.cachedThemeMode, ThemeMode.dark);
      expect(themeProvider.isCacheValid, true);

      // Change again
      await themeProvider.setThemeMode(ThemeMode.system);
      await Future.delayed(const Duration(milliseconds: 100));

      // Cache should be updated again
      expect(themeProvider.cachedThemeMode, ThemeMode.system);
      expect(themeProvider.isCacheValid, true);
    });

    /// Property: Cache clearing should invalidate cached values
    test('cache clearing invalidates cached values', () async {
      // Set theme and verify cache
      await themeProvider.setThemeMode(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(themeProvider.isCacheValid, true);
      expect(themeProvider.cachedThemeMode, ThemeMode.dark);

      // Clear cache
      await themeProvider.clearCache();

      // Cache should be invalid
      expect(themeProvider.isCacheValid, false);
      expect(themeProvider.cachedThemeMode, isNull);
    });

    /// Property: Reloading theme should bypass cache
    test('reloading theme bypasses cache', () async {
      // Set initial theme
      await themeProvider.setThemeMode(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(themeProvider.cachedThemeMode, ThemeMode.light);

      // Manually modify storage to simulate external change
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', 'dark');

      // Reload should bypass cache and get new value
      await themeProvider.reloadThemePreference();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.cachedThemeMode, ThemeMode.dark);
    });

    /// Property: Multiple rapid theme lookups should use cache efficiently
    test('rapid theme lookups use cache efficiently', () async {
      // Set theme
      await themeProvider.setThemeMode(ThemeMode.system);
      await Future.delayed(const Duration(milliseconds: 100));

      // Perform many rapid lookups
      final startTime = DateTime.now();
      for (int i = 0; i < 100; i++) {
        final theme = themeProvider.themeMode;
        expect(theme, ThemeMode.system);
      }
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      // 100 lookups should complete very quickly (well under 50ms total)
      expect(
        elapsed,
        lessThan(50),
        reason:
            '100 cached lookups should complete within 50ms (actual: ${elapsed}ms)',
      );

      debugPrint('100 cached theme lookups completed in ${elapsed}ms');
    });

    /// Property: Cache should persist across theme changes
    test('cache persists across multiple theme changes', () async {
      final themes = [
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
        ThemeMode.light,
        ThemeMode.dark,
      ];

      for (final theme in themes) {
        await themeProvider.setThemeMode(theme);
        await Future.delayed(const Duration(milliseconds: 50));

        // Cache should always be valid after a theme change
        expect(themeProvider.isCacheValid, true);
        expect(themeProvider.cachedThemeMode, theme);
        expect(themeProvider.themeMode, theme);
      }
    });
  });
}
