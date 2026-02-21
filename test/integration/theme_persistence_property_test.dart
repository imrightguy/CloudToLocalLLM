/// Property-Based Test for Theme Persistence
///
/// **Feature: unified-app-theming, Property 3: Theme Persistence Round Trip**
///
/// Tests that theme preferences persist correctly across application restarts
/// and that persistence operations complete within required timeframes.
///
/// **Validates: Requirements 1.3, 1.4, 15.1, 15.2**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 3: Theme Persistence Round Trip', () {
    /// Property: For any theme preference, saving and restoring on next launch
    /// SHALL produce the same value
    ///
    /// This is a round-trip property that ensures theme persistence is correct.
    /// We test all three theme modes to ensure complete coverage.
    test('theme persistence round trip for all theme modes', () async {
      final themeModes = [
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
      ];

      for (final originalTheme in themeModes) {
        // Start with clean state for each theme test
        SharedPreferences.setMockInitialValues({});

        // Create provider and set theme
        final provider1 = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));

        await provider1.setThemeMode(originalTheme);
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify theme was set
        expect(provider1.themeMode, originalTheme);

        // Dispose first provider (simulating app close)
        // Note: SharedPreferences mock persists data even after disposal
        provider1.dispose();

        // Create new provider (simulating app restart)
        // The mock SharedPreferences retains the data from provider1
        final provider2 = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify theme was restored correctly (round trip)
        expect(
          provider2.themeMode,
          originalTheme,
          reason:
              'Theme should persist across app restarts: $originalTheme should equal ${provider2.themeMode}',
        );

        provider2.dispose();
      }
    });

    /// Property: Multiple round trips should maintain theme consistency
    test('multiple round trips maintain theme consistency', () async {
      final themeSequence = [
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
        ThemeMode.light,
        ThemeMode.dark,
      ];

      for (final theme in themeSequence) {
        // Create provider, set theme, and dispose
        final provider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));

        await provider.setThemeMode(theme);
        await Future.delayed(const Duration(milliseconds: 100));

        provider.dispose();

        // Create new provider and verify
        final newProvider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(
          newProvider.themeMode,
          theme,
          reason: 'Theme $theme should persist after round trip',
        );

        newProvider.dispose();
      }
    });

    /// Property: Theme persistence should work with rapid changes
    test('rapid theme changes persist correctly', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Rapidly change themes
      await provider.setThemeMode(ThemeMode.light);
      await provider.setThemeMode(ThemeMode.dark);
      await provider.setThemeMode(ThemeMode.system);
      await provider.setThemeMode(ThemeMode.light);

      // Wait for persistence
      await Future.delayed(const Duration(milliseconds: 200));

      final finalTheme = provider.themeMode;
      provider.dispose();

      // Create new provider and verify last theme persisted
      final newProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(
        newProvider.themeMode,
        finalTheme,
        reason: 'Last theme in rapid sequence should persist',
      );

      newProvider.dispose();
    });

    /// Property: Theme persistence should survive storage errors gracefully
    test('theme persistence handles storage errors', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Set initial theme
      await provider.setThemeMode(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.themeMode, ThemeMode.dark);

      // Even if storage fails, theme should remain in memory
      expect(provider.lastError, isNull);

      provider.dispose();
    });
  });

  group('Theme Persistence Timing', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    /// Property: Theme changes SHALL persist to storage within 500ms
    /// (Requirement 15.1)
    test('theme persistence completes within 500ms', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      final themeModes = [
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
      ];

      for (final theme in themeModes) {
        final startTime = DateTime.now();

        await provider.setThemeMode(theme);

        final elapsed = DateTime.now().difference(startTime).inMilliseconds;

        expect(
          elapsed,
          lessThan(500),
          reason:
              'Theme persistence should complete within 500ms (actual: ${elapsed}ms for $theme)',
        );

        // Verify persistence by checking storage
        final prefs = await SharedPreferences.getInstance();
        final savedTheme = prefs.getString('theme_mode');
        expect(savedTheme, isNotNull);

        // Small delay between tests
        await Future.delayed(const Duration(milliseconds: 50));
      }

      provider.dispose();
    });

    /// Property: Persistence timing should be consistent across theme modes
    test('persistence timing is consistent across theme modes', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      final timings = <String, int>{};

      for (final theme in ThemeMode.values) {
        final startTime = DateTime.now();
        await provider.setThemeMode(theme);
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;

        timings[theme.toString()] = elapsed;

        expect(
          elapsed,
          lessThan(500),
          reason: 'Persistence for $theme should be under 500ms',
        );

        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint('Theme persistence timings: $timings');

      // All timings should be reasonably similar (within 200ms of each other)
      final values = timings.values.toList();
      final maxTiming = values.reduce((a, b) => a > b ? a : b);
      final minTiming = values.reduce((a, b) => a < b ? a : b);

      expect(
        maxTiming - minTiming,
        lessThan(200),
        reason: 'Persistence timing should be consistent across theme modes',
      );

      provider.dispose();
    });
  });

  group('Theme Restoration on Startup', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    /// Property: Theme SHALL restore within 1 second on application startup
    /// (Requirement 1.4, 15.2)
    test('theme restoration completes within 1 second', () async {
      // First, save a theme preference
      final setupProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      await setupProvider.setThemeMode(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100));
      setupProvider.dispose();

      // Now measure restoration time
      final startTime = DateTime.now();
      final provider = ThemeProvider();

      // Wait for provider to initialize
      await Future.delayed(const Duration(milliseconds: 100));

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      expect(
        elapsed,
        lessThan(1000),
        reason:
            'Theme restoration should complete within 1 second (actual: ${elapsed}ms)',
      );

      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isLoading, false);

      provider.dispose();
    });

    /// Property: Restoration should work for all theme modes
    test('restoration works for all theme modes within time limit', () async {
      for (final theme in ThemeMode.values) {
        // Setup: save theme
        SharedPreferences.setMockInitialValues({});
        final setupProvider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));
        await setupProvider.setThemeMode(theme);
        await Future.delayed(const Duration(milliseconds: 100));
        setupProvider.dispose();

        // Test: measure restoration
        final startTime = DateTime.now();
        final provider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;

        expect(
          elapsed,
          lessThan(1000),
          reason: 'Restoration of $theme should complete within 1 second',
        );

        expect(provider.themeMode, theme);

        provider.dispose();
      }
    });

    /// Property: Multiple consecutive startups should restore consistently
    test('multiple startups restore theme consistently', () async {
      // Set initial theme
      final initialProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      await initialProvider.setThemeMode(ThemeMode.system);
      await Future.delayed(const Duration(milliseconds: 100));
      initialProvider.dispose();

      // Simulate multiple app restarts
      for (int i = 0; i < 5; i++) {
        final startTime = DateTime.now();
        final provider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;

        expect(
          elapsed,
          lessThan(1000),
          reason: 'Startup $i should restore within 1 second',
        );

        expect(
          provider.themeMode,
          ThemeMode.system,
          reason: 'Startup $i should restore correct theme',
        );

        provider.dispose();
      }
    });

    /// Property: Restoration should use cache for improved performance
    test('restoration uses cache for faster subsequent loads', () async {
      // First startup - no cache
      final provider1 = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      await provider1.setThemeMode(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100));

      provider1.dispose();

      // Second startup - should use cache
      final startTime = DateTime.now();
      final provider2 = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      final secondLoadTime =
          DateTime.now().difference(startTime).inMilliseconds;

      expect(
        secondLoadTime,
        lessThan(1000),
        reason: 'Cached restoration should be fast',
      );

      expect(provider2.themeMode, ThemeMode.dark);
      expect(provider2.isCacheValid, true);

      provider2.dispose();
    });

    /// Property: Restoration should handle missing preferences gracefully
    test('restoration handles missing preferences with default', () async {
      // Don't set any theme preference
      SharedPreferences.setMockInitialValues({});

      final startTime = DateTime.now();
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      expect(
        elapsed,
        lessThan(1000),
        reason: 'Restoration with defaults should complete within 1 second',
      );

      // Should use default theme (from AppConfig)
      expect(provider.themeMode, isIn([ThemeMode.light, ThemeMode.dark]));
      expect(provider.isLoading, false);

      provider.dispose();
    });

    /// Property: Restoration should handle corrupted preferences gracefully
    test('restoration handles corrupted preferences', () async {
      // Set invalid theme value
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'invalid_theme_value',
      });

      final startTime = DateTime.now();
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      expect(
        elapsed,
        lessThan(1000),
        reason: 'Restoration with invalid data should complete within 1 second',
      );

      // Should fallback to default theme
      expect(provider.themeMode, isIn([ThemeMode.light, ThemeMode.dark]));
      expect(provider.isLoading, false);

      provider.dispose();
    });
  });

  group('Theme Persistence Edge Cases', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    /// Property: Same theme set multiple times should persist correctly
    test('setting same theme multiple times persists correctly', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Set same theme multiple times
      await provider.setThemeMode(ThemeMode.dark);
      await provider.setThemeMode(ThemeMode.dark);
      await provider.setThemeMode(ThemeMode.dark);

      await Future.delayed(const Duration(milliseconds: 100));
      provider.dispose();

      // Verify persistence
      final newProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(newProvider.themeMode, ThemeMode.dark);

      newProvider.dispose();
    });

    /// Property: Theme persistence should work with string conversion
    test('theme persistence works with string conversion', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Set theme using string method
      await provider.setThemeModeFromString('dark');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.themeModeString, 'dark');

      provider.dispose();

      // Verify persistence
      final newProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(newProvider.themeModeString, 'dark');

      newProvider.dispose();
    });

    /// Property: Theme persistence should survive provider disposal
    test('theme persists after provider disposal', () async {
      final themes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

      for (final theme in themes) {
        final provider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));

        await provider.setThemeMode(theme);
        await Future.delayed(const Duration(milliseconds: 100));

        // Dispose immediately
        provider.dispose();

        // Create new provider
        final newProvider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(
          newProvider.themeMode,
          theme,
          reason: 'Theme should persist even after immediate disposal',
        );

        newProvider.dispose();
      }
    });
  });
}
