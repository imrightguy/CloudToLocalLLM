import 'package:cloudtolocalllm/config/theme.dart';
import 'package:cloudtolocalllm/config/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme exposes spacing extension on dark theme', () {
    final theme = AppTheme.darkTheme;

    final spacing =
        theme.extension<AppSpacingTheme>() ?? AppSpacingTheme.standard;
    final colors = theme.extension<AppColorsTheme>() ?? AppColorsTheme.dark;

    expect(spacing.m, 16);
    expect(colors.primary, const Color(0xFFa777e3));
  });
}
