import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/config/theme.dart';

/// Integration test for theme application across MaterialApp
/// Validates Requirements 1.1, 1.2, 1.3, 1.4
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Application Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('MaterialApp applies light theme correctly',
        (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      await tester.pumpAndSettle();

      await themeProvider.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const Scaffold(
            body: Text('Test'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify light theme is applied
      final BuildContext context = tester.element(find.text('Test'));
      final theme = Theme.of(context);
      expect(theme.brightness, Brightness.light);
    });

    testWidgets('MaterialApp applies dark theme correctly',
        (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      await tester.pumpAndSettle();

      await themeProvider.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const Scaffold(
            body: Text('Test'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dark theme is applied
      final BuildContext context = tester.element(find.text('Test'));
      final theme = Theme.of(context);
      expect(theme.brightness, Brightness.dark);
    });

    testWidgets('Theme switches within 200ms', (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      await tester.pumpAndSettle();

      await themeProvider.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const Scaffold(
            body: Text('Test'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Measure theme switch time
      final stopwatch = Stopwatch()..start();
      await themeProvider.setThemeMode(ThemeMode.dark);
      stopwatch.stop();

      // Verify theme switch completed within 200ms (Requirement 1.2)
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    // Note: Theme persistence is tested in test/services/theme_provider_test.dart
    // This integration test focuses on MaterialApp theme application

    testWidgets('System theme mode is supported', (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      await tester.pumpAndSettle();

      await themeProvider.setThemeMode(ThemeMode.system);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const Scaffold(
            body: Text('Test'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify system theme mode is set (Requirement 1.5)
      expect(themeProvider.themeMode, ThemeMode.system);
    });
  });
}
