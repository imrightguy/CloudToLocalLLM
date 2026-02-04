import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoidbot/screens/ollama_test_screen.dart';
import 'package:zoidbot/services/theme_provider.dart';
import 'package:zoidbot/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

/// **Feature: unified-app-theming, Property 4: Platform-Appropriate Components**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Diagnostic Screens Platform Component Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 4: Diagnostic screens use Material components',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createPlatformTestApp(
            const OllamaTestScreen(),
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(OllamaTestScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 4: Diagnostic screens respond to theme changes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullTestApp(
            const OllamaTestScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        final scaffoldFinderLight = find.byType(Scaffold);
        expect(scaffoldFinderLight, findsOneWidget);

        await themeProvider.setThemeMode(ThemeMode.dark);

        await pumpAndSettleWithTimeout(tester);

        final scaffoldFinderDark = find.byType(Scaffold);
        expect(scaffoldFinderDark, findsOneWidget);
      },
    );
  });
}
