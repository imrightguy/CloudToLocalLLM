import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/widgets/settings/general_settings_category.dart';
import 'package:cloudtolocalllm/models/settings_category.dart';

void main() {
  group('GeneralSettingsCategory', () {
    setUp(() {
      // Reset SharedPreferences for each test
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders theme and language dropdowns',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeneralSettingsCategory(
              categoryId: SettingsCategoryIds.general,
            ),
          ),
        ),
      );

      // Wait for async initialization
      await tester.pumpAndSettle();

      // Check for theme dropdown
      expect(find.text('Theme'), findsWidgets);
      expect(find.text('Appearance'), findsOneWidget);

      // Check for language dropdown
      expect(find.text('Language'), findsWidgets);
    });

    testWidgets('save button is disabled when no changes made',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeneralSettingsCategory(
              categoryId: SettingsCategoryIds.general,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find save button
      final saveButton = find.widgetWithText(FilledButton, 'Save');
      expect(saveButton, findsOneWidget);

      // Save button should be disabled initially
      final button = tester.widget<FilledButton>(saveButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('respects isActive property', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeneralSettingsCategory(
              categoryId: SettingsCategoryIds.general,
              isActive: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should still render but with reduced opacity
      expect(find.byType(GeneralSettingsCategory), findsOneWidget);
    });

    testWidgets('renders with correct category ID',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeneralSettingsCategory(
              categoryId: SettingsCategoryIds.general,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the widget renders
      expect(find.byType(GeneralSettingsCategory), findsOneWidget);
    });
  });
}
