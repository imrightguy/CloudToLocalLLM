import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/marketing/homepage_screen.dart';
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

  group('Homepage Theme Application Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 1: Homepage applies light theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const HomepageScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expectThemeMode(tester, Brightness.light);
        expect(find.byType(HomepageScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Homepage applies dark theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.dark);

        await tester.pumpWidget(
          createFullTestApp(
            const HomepageScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expectThemeMode(tester, Brightness.dark);
        expect(find.byType(HomepageScreen), findsOneWidget);
      },
    );
  });
}
