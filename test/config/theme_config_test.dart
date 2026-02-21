import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/config/theme_config.dart';

void main() {
  group('ThemeConfig', () {
    test('loads dark theme configuration', () {
      final theme = ThemeConfig.loadThemeConfiguration(
        ThemeMode.dark,
        null,
      );

      expect(theme, isNotNull);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, ThemeConfig.primaryColor);
      expect(theme.colorScheme.secondary, ThemeConfig.secondaryColor);
    });

    test('loads light theme configuration', () {
      final theme = ThemeConfig.loadThemeConfiguration(
        ThemeMode.light,
        null,
      );

      expect(theme, isNotNull);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, ThemeConfig.primaryColor);
      expect(theme.colorScheme.secondary, ThemeConfig.secondaryColor);
    });

    test('respects system theme mode with dark brightness', () {
      final theme = ThemeConfig.loadThemeConfiguration(
        ThemeMode.system,
        Brightness.dark,
      );

      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('respects system theme mode with light brightness', () {
      final theme = ThemeConfig.loadThemeConfiguration(
        ThemeMode.system,
        Brightness.light,
      );

      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('validates contrast ratio correctly', () {
      // White on black should pass (21:1 ratio)
      expect(
        ThemeConfig.validateContrastRatio(Colors.white, Colors.black),
        isTrue,
      );

      // Light gray on white should fail (< 4.5:1 ratio)
      expect(
        ThemeConfig.validateContrastRatio(
          const Color(0xFFCCCCCC),
          Colors.white,
        ),
        isFalse,
      );
    });

    test('validates dark theme successfully', () {
      final theme = ThemeConfig.loadThemeConfiguration(
        ThemeMode.dark,
        null,
      );

      final result = ThemeConfig.validateTheme(theme, isDark: true);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('validates light theme successfully', () {
      final theme = ThemeConfig.loadThemeConfiguration(
        ThemeMode.light,
        null,
      );

      final result = ThemeConfig.validateTheme(theme, isDark: false);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('provides platform-specific spacing adjustments', () {
      const baseSpacing = 16.0;

      // Desktop platforms should have larger spacing
      final windowsSpacing = ThemeConfig.getPlatformSpacing(
        TargetPlatform.windows,
        baseSpacing,
      );
      expect(windowsSpacing, greaterThan(baseSpacing));

      final linuxSpacing = ThemeConfig.getPlatformSpacing(
        TargetPlatform.linux,
        baseSpacing,
      );
      expect(linuxSpacing, greaterThan(baseSpacing));

      // Mobile platforms should use standard spacing
      final androidSpacing = ThemeConfig.getPlatformSpacing(
        TargetPlatform.android,
        baseSpacing,
      );
      expect(androidSpacing, equals(baseSpacing));
    });

    test('provides platform-specific font size adjustments', () {
      const baseFontSize = 16.0;

      // Desktop platforms should have larger fonts
      final windowsFontSize = ThemeConfig.getPlatformFontSize(
        TargetPlatform.windows,
        baseFontSize,
      );
      expect(windowsFontSize, greaterThan(baseFontSize));

      // Mobile platforms should use standard fonts
      final androidFontSize = ThemeConfig.getPlatformFontSize(
        TargetPlatform.android,
        baseFontSize,
      );
      expect(androidFontSize, equals(baseFontSize));
    });

    test('provides platform-specific elevation adjustments', () {
      const baseElevation = 8.0;

      // Desktop platforms should have more subtle elevation
      final windowsElevation = ThemeConfig.getPlatformElevation(
        TargetPlatform.windows,
        baseElevation,
      );
      expect(windowsElevation, lessThan(baseElevation));

      // iOS should have minimal elevation
      final iosElevation = ThemeConfig.getPlatformElevation(
        TargetPlatform.iOS,
        baseElevation,
      );
      expect(iosElevation, lessThan(windowsElevation));

      // Android should use standard elevation
      final androidElevation = ThemeConfig.getPlatformElevation(
        TargetPlatform.android,
        baseElevation,
      );
      expect(androidElevation, equals(baseElevation));
    });
  });
}
