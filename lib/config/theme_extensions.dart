import 'dart:ui';
import 'package:flutter/material.dart';

class AppSpacingTheme extends ThemeExtension<AppSpacingTheme> {
  const AppSpacingTheme({
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.xxl,
  });

  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;

  static const AppSpacingTheme standard = AppSpacingTheme(
    xs: 4,
    s: 8,
    m: 16,
    l: 24,
    xl: 32,
    xxl: 48,
  );

  @override
  AppSpacingTheme copyWith({
    double? xs,
    double? s,
    double? m,
    double? l,
    double? xl,
    double? xxl,
  }) {
    return AppSpacingTheme(
      xs: xs ?? this.xs,
      s: s ?? this.s,
      m: m ?? this.m,
      l: l ?? this.l,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AppSpacingTheme lerp(ThemeExtension<AppSpacingTheme>? other, double t) {
    if (other is! AppSpacingTheme) return this;
    return AppSpacingTheme(
      xs: lerpDouble(xs, other.xs, t)!,
      s: lerpDouble(s, other.s, t)!,
      m: lerpDouble(m, other.m, t)!,
      l: lerpDouble(l, other.l, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}

class AppColorsTheme extends ThemeExtension<AppColorsTheme> {
  const AppColorsTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.backgroundMain,
    required this.backgroundCard,
    required this.backgroundLight,
    required this.textColor,
    required this.textColorLight,
    required this.textColorDark,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.glassBackground,
    required this.glassBorder,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color backgroundMain;
  final Color backgroundCard;
  final Color backgroundLight;
  final Color textColor;
  final Color textColorLight;
  final Color textColorDark;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color glassBackground;
  final Color glassBorder;

  static const AppColorsTheme dark = AppColorsTheme(
    primary: Color(0xFFD4AF37), // Pistis Gold
    secondary: Color(0xFFE8C547), // Warm Amber Gold
    accent: Color(0xFFC9A227), // Deep Gold
    backgroundMain: Color(0xFF0F0F1A), // Warm dark
    backgroundCard: Color(0xFF1A1A2E), // Card
    backgroundLight: Color(0xFFf5f5f5),
    textColor: Color(0xFFF5E6C8), // Warm cream
    textColorLight: Color(0xFFB8A88A), // Muted gold-grey
    textColorDark: Color(0xFF2c3e50),
    success: Color(0xFF4caf50),
    warning: Color(0xFFffa726),
    danger: Color(0xFFff5252),
    info: Color(0xFF2196f3),
    glassBackground: Color(0x33D4AF37), // Gold-tinted glass (20%)
    glassBorder: Color(0x26D4AF37), // Gold-tinted border (15%)
  );

  static const AppColorsTheme light = AppColorsTheme(
    primary: Color(0xFFD4AF37), // Pistis Gold
    secondary: Color(0xFFE8C547), // Warm Amber Gold
    accent: Color(0xFFC9A227), // Deep Gold
    backgroundMain: Colors.white,
    backgroundCard: Color(0xFFF1F2F4),
    backgroundLight: Color(0xFFf5f5f5),
    textColor: Color(0xFF2c3e50),
    textColorLight: Color(0xFF6F7B8A),
    textColorDark: Color(0xFF263238),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFF57C00),
    danger: Color(0xFFD32F2F),
    info: Color(0xFF1976D2),
    glassBackground: Color(0x66D4AF37), // Gold-tinted glass (40%)
    glassBorder: Color(0x80D4AF37), // Gold-tinted border (50%)
  );

  @override
  AppColorsTheme copyWith({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? backgroundMain,
    Color? backgroundCard,
    Color? backgroundLight,
    Color? textColor,
    Color? textColorLight,
    Color? textColorDark,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? glassBackground,
    Color? glassBorder,
  }) {
    return AppColorsTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      backgroundMain: backgroundMain ?? this.backgroundMain,
      backgroundCard: backgroundCard ?? this.backgroundCard,
      backgroundLight: backgroundLight ?? this.backgroundLight,
      textColor: textColor ?? this.textColor,
      textColorLight: textColorLight ?? this.textColorLight,
      textColorDark: textColorDark ?? this.textColorDark,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
    );
  }

  @override
  AppColorsTheme lerp(ThemeExtension<AppColorsTheme>? other, double t) {
    if (other is! AppColorsTheme) return this;
    return AppColorsTheme(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      backgroundMain: Color.lerp(backgroundMain, other.backgroundMain, t)!,
      backgroundCard: Color.lerp(backgroundCard, other.backgroundCard, t)!,
      backgroundLight: Color.lerp(backgroundLight, other.backgroundLight, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      textColorLight: Color.lerp(textColorLight, other.textColorLight, t)!,
      textColorDark: Color.lerp(textColorDark, other.textColorDark, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    );
  }
}
