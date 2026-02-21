import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/unified_settings_screen.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Settings Screen Theme Application Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 1: Settings screen applies light theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const UnifiedSettingsScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expectThemeMode(tester, Brightness.light);
        expect(find.byType(UnifiedSettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Settings screen applies dark theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.dark);

        await tester.pumpWidget(
          createFullTestApp(
            const UnifiedSettingsScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expectThemeMode(tester, Brightness.dark);
        expect(find.byType(UnifiedSettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Settings screen updates theme within 200ms',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const UnifiedSettingsScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        final duration = await measureExecutionTime(() async {
          await themeProvider.setThemeMode(ThemeMode.dark);
          await tester.pump();
          await pumpAndSettleWithTimeout(tester);
        });

        expectExecutionTimeWithin(duration, const Duration(milliseconds: 200));
        expectThemeMode(tester, Brightness.dark);
      },
    );
  });
}
