import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/utils/accessibility_helpers.dart';

void main() {
  group('AccessibilityHelpers', () {
    test('getSemanticLabel combines label and description', () {
      const label = 'Theme';
      const description = 'Choose your preferred theme';

      final result = AccessibilityHelpers.getSemanticLabel(
        label,
        description: description,
      );

      expect(result, 'Theme. Choose your preferred theme');
    });

    test('getSemanticLabel returns label when description is null', () {
      const label = 'Theme';

      final result = AccessibilityHelpers.getSemanticLabel(label);

      expect(result, 'Theme');
    });

    test('getSemanticLabel returns label when description is empty', () {
      const label = 'Theme';

      final result = AccessibilityHelpers.getSemanticLabel(
        label,
        description: '',
      );

      expect(result, 'Theme');
    });

    test('meetsContrastRequirement returns true for sufficient contrast', () {
      // Black text on white background (21:1 contrast)
      const foreground = Color(0xFF000000);
      const background = Color(0xFFFFFFFF);

      final result = AccessibilityHelpers.meetsContrastRequirement(
        foreground,
        background,
      );

      expect(result, true);
    });

    test('meetsContrastRequirement returns false for insufficient contrast',
        () {
      // Light gray text on white background (low contrast)
      const foreground = Color(0xFFEEEEEE);
      const background = Color(0xFFFFFFFF);

      final result = AccessibilityHelpers.meetsContrastRequirement(
        foreground,
        background,
      );

      expect(result, false);
    });

    test('meetsContrastRequirement handles edge case colors', () {
      // Test with colors that have different luminance values
      const darkText = Color(0xFF333333);
      const lightBackground = Color(0xFFFAFAFA);

      final result = AccessibilityHelpers.meetsContrastRequirement(
        darkText,
        lightBackground,
      );

      expect(result, true);
    });
  });
}
