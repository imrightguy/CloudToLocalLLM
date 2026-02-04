import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoidbot/screens/ollama_test_screen.dart';
import 'package:zoidbot/services/theme_provider.dart';

import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Diagnostic Screens Theme Application Property Tests', () {
    late ThemeProvider themeProvider;
    late MockPlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = MockPlatformDetectionService();
    });

    testWidgets(
      'Property 1: Diagnostic screens apply light theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const OllamaTestScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expectThemeMode(tester, Brightness.light);
        expect(find.byType(OllamaTestScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Diagnostic screens apply dark theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.dark);

        await tester.pumpWidget(
          createFullTestApp(
            const OllamaTestScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expectThemeMode(tester, Brightness.dark);
        expect(find.byType(OllamaTestScreen), findsOneWidget);
      },
    );
  });
}
