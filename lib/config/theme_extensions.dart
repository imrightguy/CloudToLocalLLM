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
    primary: Color(0xFFa777e3),
    secondary: Color(0xFF6e8efb),
    accent: Color(0xFF00c58e),
    backgroundMain: Color(0xFF181a20),
    backgroundCard: Color(0xFF23243a),
    backgroundLight: Color(0xFFf5f5f5),
    textColor: Color(0xFFf1f1f1),
    textColorLight: Color(0xFFb0b0b0),
    textColorDark: Color(0xFF2c3e50),
    success: Color(0xFF4caf50),
    warning: Color(0xFFffa726),
    danger: Color(0xFFff5252),
    info: Color(0xFF2196f3),
    glassBackground: Color(0x33FFFFFF),
    glassBorder: Color(0x4DFFFFFF),
  );

  static const AppColorsTheme light = AppColorsTheme(
    primary: Color(0xFFa777e3),
    secondary: Color(0xFF6e8efb),
    accent: Color(0xFF00c58e),
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
    glassBackground: Color(0x66FFFFFF),
    glassBorder: Color(0x80FFFFFF),
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
