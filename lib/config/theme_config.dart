/// Unified Theme Configuration
///
/// Centralized theme configuration for Light, Dark, and System themes.
/// Provides platform-specific theme variations and validation.
///
/// Features:
/// - Light and Dark mode color schemes
/// - Typography configuration
/// - Platform-specific variations (Web, Windows, Linux)
/// - Theme validation
/// - Configuration loading and caching
library;

import 'dart:math' as dart_math;
import 'package:flutter/material.dart';
import 'theme_extensions.dart';

/// Unified theme configuration for the application
class ThemeConfig {
  /// Private constructor to prevent instantiation
  ThemeConfig._();

  // ============================================================================
  // Color Definitions
  // ============================================================================

  /// Primary brand color (Lobster Red)
  static const Color primaryColor = Color(0xFFFF0000);

  /// Secondary brand color (Lobster Orange)
  static const Color secondaryColor = Color(0xFFFF7F00);

  /// Accent color (Black)
  static const Color accentColor = Color(0xFF000000);

  // Dark Mode Colors
  static const Color darkBackgroundMain = Color(0xFF000000);
  static const Color darkBackgroundCard = Color(0xFF000000);
  static const Color darkTextColor = Color(0xFFf1f1f1);
  static const Color darkTextColorLight = Color(0xFFb0b0b0);
  static const Color darkBorderColor = Color(0xFF1E1E1E);

  // Light Mode Colors
  static const Color lightBackgroundMain = Colors.white;
  static const Color lightBackgroundCard = Color(0xFFF1F2F4);
  static const Color lightBackgroundLight = Color(0xFFf5f5f5);
  static const Color lightTextColor = Color(0xFF2c3e50);
  static const Color lightTextColorLight = Color(0xFF6F7B8A);
  static const Color lightTextColorDark = Color(0xFF263238);
  static const Color lightBorderColor = Color(0xFFE0E0E0);

  // Status Colors (same for both themes)
  static const Color successColor = Color(0xFF4caf50);
  static const Color successColorLight = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFffa726);
  static const Color warningColorLight = Color(0xFFF57C00);
  static const Color dangerColor = Color(0xFFff5252);
  static const Color dangerColorLight = Color(0xFFD32F2F);
  static const Color infoColor = Color(0xFF2196f3);
  static const Color infoColorLight = Color(0xFF1976D2);

  // ============================================================================
  // Typography Definitions
  // ============================================================================

  /// Font family fallback chain for cross-platform compatibility
  static const List<String> fontFamilyFallback = [
    'Segoe UI', // Windows
    'Roboto', // Android/Web
    'Helvetica Neue', // iOS/macOS
    'Arial', // Universal fallback
    'sans-serif', // System fallback
  ];

  /// Display text styles (large headings)
  static const TextStyle displayLargeStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle displayMediumStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  /// Headline text styles (section headings)
  static const TextStyle headlineLargeStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle headlineMediumStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle headlineSmallStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Body text styles (content)
  static const TextStyle bodyLargeStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle bodyMediumStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle bodySmallStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  // ============================================================================
  // Spacing System
  // ============================================================================

  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ============================================================================
  // Border Radius
  // ============================================================================

  static const double borderRadiusS = 8.0;
  static const double borderRadiusM = 16.0;
  static const double borderRadiusL = 24.0;

  // ============================================================================
  // Elevation
  // ============================================================================

  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationVeryHigh = 16.0;

  // ============================================================================
  // Platform-Specific Variations
  // ============================================================================

  /// Get platform-specific spacing adjustments
  static double getPlatformSpacing(
      TargetPlatform platform, double baseSpacing) {
    switch (platform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        // Desktop platforms use slightly larger spacing
        return baseSpacing * 1.1;
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        // Mobile platforms use standard spacing
        return baseSpacing;
      default:
        // Web and others use standard spacing
        return baseSpacing;
    }
  }

  /// Get platform-specific font size adjustments
  static double getPlatformFontSize(
      TargetPlatform platform, double baseFontSize) {
    switch (platform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        // Desktop platforms use slightly larger fonts
        return baseFontSize * 1.05;
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        // Mobile platforms use standard fonts
        return baseFontSize;
      default:
        // Web uses standard fonts
        return baseFontSize;
    }
  }

  /// Get platform-specific elevation
  static double getPlatformElevation(
      TargetPlatform platform, double baseElevation) {
    switch (platform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        // Desktop platforms use more subtle elevation
        return baseElevation * 0.8;
      case TargetPlatform.iOS:
        // iOS uses minimal elevation
        return baseElevation * 0.5;
      case TargetPlatform.android:
        // Android uses standard elevation
        return baseElevation;
      default:
        // Web uses standard elevation
        return baseElevation;
    }
  }

  // ============================================================================
  // Theme Validation
  // ============================================================================

  /// Validate that a color has sufficient contrast ratio
  /// WCAG AA requires 4.5:1 for normal text, 3:1 for large text
  static bool validateContrastRatio(Color foreground, Color background,
      {bool isLargeText = false}) {
    final double ratio = _calculateContrastRatio(foreground, background);
    final double requiredRatio = isLargeText ? 3.0 : 4.5;
    return ratio >= requiredRatio;
  }

  /// Calculate contrast ratio between two colors
  /// Formula: (L1 + 0.05) / (L2 + 0.05) where L1 is lighter
  static double _calculateContrastRatio(Color color1, Color color2) {
    final double l1 = _calculateRelativeLuminance(color1);
    final double l2 = _calculateRelativeLuminance(color2);
    final double lighter = l1 > l2 ? l1 : l2;
    final double darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Calculate relative luminance of a color
  /// Formula: 0.2126 * R + 0.7152 * G + 0.0722 * B
  static double _calculateRelativeLuminance(Color color) {
    final double r = _linearizeColorComponent((color.r * 255).round() / 255.0);
    final double g = _linearizeColorComponent((color.g * 255).round() / 255.0);
    final double b = _linearizeColorComponent((color.b * 255).round() / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize a color component for luminance calculation
  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return ((component + 0.055) / 1.055).pow(2.4);
  }

  /// Validate theme configuration
  static ThemeValidationResult validateTheme(ThemeData theme,
      {required bool isDark}) {
    final List<String> errors = [];
    final List<String> warnings = [];

    final colorScheme = theme.colorScheme;

    // Validate contrast ratios
    if (!validateContrastRatio(colorScheme.onPrimary, colorScheme.primary)) {
      warnings.add('Primary color contrast ratio is below WCAG AA standard');
    }

    if (!validateContrastRatio(
        colorScheme.onSecondary, colorScheme.secondary)) {
      warnings.add('Secondary color contrast ratio is below WCAG AA standard');
    }

    if (!validateContrastRatio(colorScheme.onSurface, colorScheme.surface)) {
      warnings.add('Surface color contrast ratio is below WCAG AA standard');
    }

    // Validate brightness matches expected mode
    if (isDark && colorScheme.brightness != Brightness.dark) {
      warnings.add('Dark theme has incorrect brightness setting');
    }

    if (!isDark && colorScheme.brightness != Brightness.light) {
      warnings.add('Light theme has incorrect brightness setting');
    }

    return ThemeValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  // ============================================================================
  // Configuration Loading
  // ============================================================================

  /// Load theme configuration for a specific mode
  static ThemeData loadThemeConfiguration(
      ThemeMode mode, Brightness? systemBrightness) {
    final bool isDark = _shouldUseDarkMode(mode, systemBrightness);
    return isDark ? _loadDarkTheme() : _loadLightTheme();
  }

  /// Determine if dark mode should be used
  static bool _shouldUseDarkMode(ThemeMode mode, Brightness? systemBrightness) {
    switch (mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return systemBrightness == Brightness.dark;
    }
  }

  /// Load dark theme configuration
  static ThemeData _loadDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: darkBackgroundCard,
      onSurface: darkTextColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [
        AppSpacingTheme.standard,
        AppColorsTheme.dark,
      ],
      scaffoldBackgroundColor: darkBackgroundMain,
      fontFamily: null,
      fontFamilyFallback: fontFamilyFallback,
      textTheme: _buildDarkTextTheme(),
      appBarTheme: _buildDarkAppBarTheme(),
      cardTheme: _buildDarkCardTheme(),
      elevatedButtonTheme: _buildDarkElevatedButtonTheme(),
      inputDecorationTheme: _buildDarkInputDecorationTheme(),
      dialogTheme: _buildDarkDialogTheme(),
      snackBarTheme: _buildDarkSnackBarTheme(),
      switchTheme: _buildDarkSwitchTheme(),
      checkboxTheme: _buildDarkCheckboxTheme(),
      radioTheme: _buildDarkRadioTheme(),
      progressIndicatorTheme: _buildDarkProgressIndicatorTheme(),
      popupMenuTheme: _buildDarkPopupMenuTheme(),
      bottomSheetTheme: _buildDarkBottomSheetTheme(),
    );
  }

  /// Load light theme configuration
  static ThemeData _loadLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: lightBackgroundLight,
      onSurface: lightTextColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [
        AppSpacingTheme.standard,
        AppColorsTheme.light,
      ],
      scaffoldBackgroundColor: lightBackgroundMain,
      fontFamily: null,
      fontFamilyFallback: fontFamilyFallback,
      textTheme: _buildLightTextTheme(),
      appBarTheme: _buildLightAppBarTheme(),
      cardTheme: _buildLightCardTheme(),
      elevatedButtonTheme: _buildLightElevatedButtonTheme(),
      inputDecorationTheme: _buildLightInputDecorationTheme(),
      dialogTheme: _buildLightDialogTheme(),
      snackBarTheme: _buildLightSnackBarTheme(),
      switchTheme: _buildLightSwitchTheme(),
      checkboxTheme: _buildLightCheckboxTheme(),
      radioTheme: _buildLightRadioTheme(),
      progressIndicatorTheme: _buildLightProgressIndicatorTheme(),
      popupMenuTheme: _buildLightPopupMenuTheme(),
      bottomSheetTheme: _buildLightBottomSheetTheme(),
    );
  }

  // ============================================================================
  // Dark Theme Builders
  // ============================================================================

  static TextTheme _buildDarkTextTheme() {
    return TextTheme(
      displayLarge: displayLargeStyle.copyWith(color: Colors.white),
      displayMedium: displayMediumStyle.copyWith(color: Colors.white),
      headlineLarge: headlineLargeStyle.copyWith(color: Colors.white),
      headlineMedium: headlineMediumStyle.copyWith(color: Colors.white),
      headlineSmall: headlineSmallStyle.copyWith(color: primaryColor),
      bodyLarge: bodyLargeStyle.copyWith(color: darkTextColor),
      bodyMedium: bodyMediumStyle.copyWith(color: darkTextColor),
      bodySmall: bodySmallStyle.copyWith(color: darkTextColorLight),
    );
  }

  static AppBarTheme _buildDarkAppBarTheme() {
    return const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  static CardThemeData _buildDarkCardTheme() {
    return CardThemeData(
      color: darkBackgroundCard,
      elevation: elevationHigh,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusM),
        side: BorderSide(
          color: secondaryColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.all(spacingS),
    );
  }

  static ElevatedButtonThemeData _buildDarkElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: elevationMedium,
        shadowColor: primaryColor.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusS),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static InputDecorationTheme _buildDarkInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: darkBackgroundCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: BorderSide(
          color: secondaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: BorderSide(
          color: secondaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: const BorderSide(color: dangerColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: const BorderSide(color: dangerColor, width: 2),
      ),
      labelStyle: const TextStyle(color: darkTextColorLight),
      hintStyle: TextStyle(color: darkTextColorLight.withValues(alpha: 0.7)),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingM,
        vertical: spacingM,
      ),
    );
  }

  static DialogThemeData _buildDarkDialogTheme() {
    return DialogThemeData(
      backgroundColor: darkBackgroundCard,
      surfaceTintColor: Colors.transparent,
      elevation: elevationVeryHigh,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusM),
        side: BorderSide(
          color: secondaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 16,
        color: darkTextColor,
        height: 1.5,
      ),
    );
  }

  static SnackBarThemeData _buildDarkSnackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: darkBackgroundCard,
      contentTextStyle: const TextStyle(color: darkTextColor),
      actionTextColor: primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
      ),
      elevation: elevationHigh,
    );
  }

  static SwitchThemeData _buildDarkSwitchTheme() {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return darkTextColorLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withValues(alpha: 0.5);
        }
        return darkBackgroundCard;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        return secondaryColor.withValues(alpha: 0.3);
      }),
    );
  }

  static CheckboxThemeData _buildDarkCheckboxTheme() {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: BorderSide(
        color: secondaryColor.withValues(alpha: 0.5),
        width: 2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  static RadioThemeData _buildDarkRadioTheme() {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return darkTextColorLight;
      }),
    );
  }

  static ProgressIndicatorThemeData _buildDarkProgressIndicatorTheme() {
    return const ProgressIndicatorThemeData(
      color: primaryColor,
      linearTrackColor: darkBackgroundCard,
      circularTrackColor: darkBackgroundCard,
    );
  }

  static PopupMenuThemeData _buildDarkPopupMenuTheme() {
    return PopupMenuThemeData(
      color: darkBackgroundCard,
      surfaceTintColor: Colors.transparent,
      elevation: elevationHigh,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        side: BorderSide(
          color: secondaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      textStyle: const TextStyle(color: darkTextColor),
    );
  }

  static BottomSheetThemeData _buildDarkBottomSheetTheme() {
    return BottomSheetThemeData(
      backgroundColor: darkBackgroundCard,
      surfaceTintColor: Colors.transparent,
      elevation: elevationVeryHigh,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(borderRadiusM),
          topRight: Radius.circular(borderRadiusM),
        ),
      ),
    );
  }

  // ============================================================================
  // Light Theme Builders
  // ============================================================================

  static TextTheme _buildLightTextTheme() {
    return TextTheme(
      displayLarge: displayLargeStyle.copyWith(color: lightTextColorDark),
      displayMedium: displayMediumStyle.copyWith(color: lightTextColorDark),
      headlineLarge: headlineLargeStyle.copyWith(color: lightTextColorDark),
      headlineMedium: headlineMediumStyle.copyWith(color: lightTextColorDark),
      headlineSmall: headlineSmallStyle.copyWith(color: primaryColor),
      bodyLarge: bodyLargeStyle.copyWith(color: lightTextColor),
      bodyMedium: bodyMediumStyle.copyWith(color: lightTextColor),
      bodySmall: bodySmallStyle.copyWith(color: lightTextColorLight),
    );
  }

  static AppBarTheme _buildLightAppBarTheme() {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: lightTextColorDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: lightTextColorDark,
      ),
    );
  }

  static CardThemeData _buildLightCardTheme() {
    return CardThemeData(
      color: Colors.white,
      elevation: elevationLow,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusM),
        side: BorderSide(
          color: lightBorderColor,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.all(spacingS),
    );
  }

  static ElevatedButtonThemeData _buildLightElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: elevationLow,
        shadowColor: primaryColor.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusS),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static InputDecorationTheme _buildLightInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: lightBackgroundCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: BorderSide(
          color: lightBorderColor,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: BorderSide(
          color: lightBorderColor,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: const BorderSide(color: dangerColorLight, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        borderSide: const BorderSide(color: dangerColorLight, width: 2),
      ),
      labelStyle: const TextStyle(color: lightTextColorLight),
      hintStyle: TextStyle(color: lightTextColorLight.withValues(alpha: 0.7)),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingM,
        vertical: spacingM,
      ),
    );
  }

  static DialogThemeData _buildLightDialogTheme() {
    return DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: elevationVeryHigh,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusM),
        side: BorderSide(
          color: lightBorderColor,
          width: 1,
        ),
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: lightTextColorDark,
      ),
      contentTextStyle: TextStyle(
        fontSize: 16,
        color: lightTextColor,
        height: 1.5,
      ),
    );
  }

  static SnackBarThemeData _buildLightSnackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: lightBackgroundCard,
      contentTextStyle: TextStyle(color: lightTextColor),
      actionTextColor: primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
      ),
      elevation: elevationHigh,
    );
  }

  static SwitchThemeData _buildLightSwitchTheme() {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return lightTextColorLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withValues(alpha: 0.5);
        }
        return lightBackgroundCard;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        return lightBorderColor;
      }),
    );
  }

  static CheckboxThemeData _buildLightCheckboxTheme() {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: BorderSide(
        color: lightBorderColor,
        width: 2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  static RadioThemeData _buildLightRadioTheme() {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return lightTextColorLight;
      }),
    );
  }

  static ProgressIndicatorThemeData _buildLightProgressIndicatorTheme() {
    return ProgressIndicatorThemeData(
      color: primaryColor,
      linearTrackColor: lightBackgroundCard,
      circularTrackColor: lightBackgroundCard,
    );
  }

  static PopupMenuThemeData _buildLightPopupMenuTheme() {
    return PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: elevationHigh,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusS),
        side: BorderSide(
          color: lightBorderColor,
          width: 1,
        ),
      ),
      textStyle: TextStyle(color: lightTextColor),
    );
  }

  static BottomSheetThemeData _buildLightBottomSheetTheme() {
    return BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: elevationVeryHigh,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(borderRadiusM),
          topRight: Radius.circular(borderRadiusM),
        ),
      ),
    );
  }
}

// ============================================================================
// Theme Validation Result
// ============================================================================

/// Result of theme validation
class ThemeValidationResult {
  const ThemeValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Theme Validation Result:');
    buffer.writeln('  Valid: $isValid');
    if (errors.isNotEmpty) {
      buffer.writeln('  Errors:');
      for (final error in errors) {
        buffer.writeln('    - $error');
      }
    }
    if (warnings.isNotEmpty) {
      buffer.writeln('  Warnings:');
      for (final warning in warnings) {
        buffer.writeln('    - $warning');
      }
    }
    return buffer.toString();
  }
}

// ============================================================================
// Extension Methods
// ============================================================================

extension on double {
  double pow(double exponent) {
    return dart_math.pow(this, exponent).toDouble();
  }
}
