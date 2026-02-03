import 'package:flutter/material.dart';
import 'theme_config.dart';
import 'theme_extensions.dart';

/// Modern Material Design 3 theme configuration matching homepage design
///
/// This class now delegates to ThemeConfig for unified theme management.
/// Use ThemeConfig directly for new implementations.
class AppTheme {
  // Color scheme matching Zoidbot lobster branding
  static const Color primaryColor = Color(
    0xFFD32F2F,
  ); // Lobster red
  static const Color secondaryColor = Color(
    0xFFFF6F00,
  ); // Deep orange
  static const Color accentColor = Color(0xFF4caf50); // Green for success

  // Background colors
  static const Color backgroundMain = Color(0xFF181a20); // --bg-main: #181a20
  static const Color backgroundCard = Color(0xFF23243a); // --bg-card: #23243a
  static const Color backgroundLight = Color(0xFFf5f5f5); // --bg-light: #f5f5f5

  // Text colors
  static const Color textColor = Color(0xFFf1f1f1); // --text-color: #f1f1f1
  static const Color textColorLight = Color(
    0xFFb0b0b0,
  ); // --text-color-light: #b0b0b0
  static const Color textColorDark = Color(
    0xFF2c3e50,
  ); // --text-color-dark: #2c3e50

  // Status colors
  static const Color successColor = Color(0xFF4caf50);
  static const Color warningColor = Color(0xFFffa726);
  static const Color dangerColor = Color(0xFFff5252);
  static const Color infoColor = Color(0xFF2196f3);

  // Border colors
  static const Color borderColor = Color(0xFF3a3a3a);

  // Gradients matching homepage
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryColor, primaryColor],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [secondaryColor, primaryColor],
  );

  // Spacing system
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border radius
  static const double borderRadiusS = 8.0;
  static const double borderRadiusM = 16.0;
  static const double borderRadiusL = 24.0;

  static AppSpacingTheme spacingOf(BuildContext context) =>
      Theme.of(context).extension<AppSpacingTheme>() ??
      AppSpacingTheme.standard;

  static AppColorsTheme colorsOf(BuildContext context) =>
      Theme.of(context).extension<AppColorsTheme>() ?? AppColorsTheme.dark;

  /// Dark theme for the application
  /// Delegates to ThemeConfig for unified theme management
  static ThemeData get darkTheme => ThemeConfig.loadThemeConfiguration(
        ThemeMode.dark,
        null,
      );

  /// Light theme for the application
  /// Delegates to ThemeConfig for unified theme management
  static ThemeData get lightTheme => ThemeConfig.loadThemeConfiguration(
        ThemeMode.light,
        null,
      );
}
