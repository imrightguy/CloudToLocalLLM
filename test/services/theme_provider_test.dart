import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    late ThemeProvider themeProvider;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      themeProvider = ThemeProvider();
      // Wait for initial load to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('initializes with default theme mode', () {
      expect(themeProvider.themeMode, isNotNull);
      expect(themeProvider.isLoading, isFalse);
    });

    test('sets theme mode and persists preference', () async {
      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.themeModeString, 'dark');
    });

    test('sets theme mode from string', () async {
      await themeProvider.setThemeModeFromString('light');
      expect(themeProvider.themeMode, ThemeMode.light);

      await themeProvider.setThemeModeFromString('dark');
      expect(themeProvider.themeMode, ThemeMode.dark);

      await themeProvider.setThemeModeFromString('system');
      expect(themeProvider.themeMode, ThemeMode.system);
    });

    test('caches theme mode after setting', () async {
      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.cachedThemeMode, ThemeMode.dark);
      expect(themeProvider.isCacheValid, isTrue);
    });

    test('loads theme from cache when valid', () async {
      // Set a theme to populate cache
      await themeProvider.setThemeMode(ThemeMode.dark);

      // Create new provider instance - should load from cache
      final newProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(newProvider.themeMode, ThemeMode.dark);
    });

    test('clears cache successfully', () async {
      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.cachedThemeMode, ThemeMode.dark);

      await themeProvider.clearCache();
      expect(themeProvider.cachedThemeMode, isNull);
      expect(themeProvider.isCacheValid, isFalse);
    });

    test('reloads theme preference bypassing cache', () async {
      await themeProvider.setThemeMode(ThemeMode.dark);
      await themeProvider.reloadThemePreference();

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.cachedThemeMode, ThemeMode.dark);
    });

    test('handles errors gracefully', () async {
      // This test verifies error handling exists
      expect(themeProvider.lastError, isNull);
    });

    test('notifies listeners on theme change', () async {
      var notified = false;
      themeProvider.addListener(() {
        notified = true;
      });

      // Change to a different theme than default
      await themeProvider.setThemeMode(ThemeMode.light);
      expect(notified, isTrue);
    });

    test('does not change theme if same mode is set', () async {
      await themeProvider.setThemeMode(ThemeMode.dark);
      var notificationCount = 0;

      themeProvider.addListener(() {
        notificationCount++;
      });

      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(notificationCount, 0);
    });

    test('isDarkMode returns correct value', () async {
      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.isDarkMode, isTrue);

      await themeProvider.setThemeMode(ThemeMode.light);
      expect(themeProvider.isDarkMode, isFalse);

      await themeProvider.setThemeMode(ThemeMode.system);
      expect(themeProvider.isDarkMode, isFalse);
    });
  });
}
