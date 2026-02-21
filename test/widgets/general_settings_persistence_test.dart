import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/widgets/settings/general_settings_category.dart';
import 'package:cloudtolocalllm/models/settings_category.dart';

void main() {
  group('General Settings - Persistence Timing', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
        'Property 10: General Settings Persistence Timing - Theme persists within 500ms',
        (WidgetTester tester) async {
      // **Feature: platform-settings-screen, Property 10: General Settings Persistence Timing**
      // **Validates: Requirements 2.6**

      final preferencesService = SettingsPreferenceService();

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

      // Measure time to save theme preference
      final stopwatch = Stopwatch()..start();

      await preferencesService.setTheme('dark');

      stopwatch.stop();

      // Verify timing constraint: persistence should complete within 500ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason:
            'Theme persistence took ${stopwatch.elapsedMilliseconds}ms, should be < 500ms',
      );

      // Verify the setting was actually persisted
      final savedTheme = await preferencesService.getTheme();
      expect(savedTheme, equals('dark'));
    });

    testWidgets(
        'Property 10: General Settings Persistence Timing - Language persists within 500ms',
        (WidgetTester tester) async {
      // **Feature: platform-settings-screen, Property 10: General Settings Persistence Timing**
      // **Validates: Requirements 2.6**

      final preferencesService = SettingsPreferenceService();

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

      // Measure time to save language preference
      final stopwatch = Stopwatch()..start();

      await preferencesService.setLanguage('es');

      stopwatch.stop();

      // Verify timing constraint: persistence should complete within 500ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason:
            'Language persistence took ${stopwatch.elapsedMilliseconds}ms, should be < 500ms',
      );

      // Verify the setting was actually persisted
      final savedLanguage = await preferencesService.getLanguage();
      expect(savedLanguage, equals('es'));
    });

    testWidgets(
        'Property 10: General Settings Persistence Timing - Multiple settings persist within 500ms each',
        (WidgetTester tester) async {
      // **Feature: platform-settings-screen, Property 10: General Settings Persistence Timing**
      // **Validates: Requirements 2.6**

      final preferencesService = SettingsPreferenceService();

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

      // Test multiple settings persistence
      final settings = [
        ('light', 'en'),
        ('dark', 'es'),
        ('system', 'fr'),
      ];

      for (final (theme, language) in settings) {
        // Measure theme persistence
        var stopwatch = Stopwatch()..start();
        await preferencesService.setTheme(theme);
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
          reason:
              'Theme persistence took ${stopwatch.elapsedMilliseconds}ms, should be < 500ms',
        );

        // Measure language persistence
        stopwatch = Stopwatch()..start();
        await preferencesService.setLanguage(language);
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
          reason:
              'Language persistence took ${stopwatch.elapsedMilliseconds}ms, should be < 500ms',
        );

        // Verify both settings were persisted
        final savedTheme = await preferencesService.getTheme();
        final savedLanguage = await preferencesService.getLanguage();
        expect(savedTheme, equals(theme));
        expect(savedLanguage, equals(language));
      }
    });

    testWidgets(
        'Property 10: General Settings Persistence Timing - Settings survive app restart',
        (WidgetTester tester) async {
      // **Feature: platform-settings-screen, Property 10: General Settings Persistence Timing**
      // **Validates: Requirements 2.6**

      final preferencesService = SettingsPreferenceService();

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

      // Save settings
      await preferencesService.setTheme('dark');
      await preferencesService.setLanguage('ja');

      // Simulate app restart by creating new service instance
      final newPreferencesService = SettingsPreferenceService();

      // Verify settings were persisted and reloaded
      final savedTheme = await newPreferencesService.getTheme();
      final savedLanguage = await newPreferencesService.getLanguage();

      expect(savedTheme, equals('dark'));
      expect(savedLanguage, equals('ja'));
    });
  });
}
