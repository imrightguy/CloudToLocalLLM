import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:cloudtolocalllm/screens/unified_settings_screen.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Settings Screen Platform Components Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;
    late PlatformAdapter platformAdapter;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
      platformAdapter = PlatformAdapter(platformService);
    });

    testWidgets(
      'Property 4: Settings screen uses Material components on web',
      (WidgetTester tester) async {
        expect(platformService.isWeb, isTrue);

        await tester.pumpWidget(
          createPlatformTestApp(
            const UnifiedSettingsScreen(),
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(UnifiedSettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 4: Settings screen components consistent across themes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullTestApp(
            const UnifiedSettingsScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
            platformAdapter: platformAdapter,
            themeMode: ThemeMode.light,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        final scaffoldFinderLight = find.byType(Scaffold);
        expect(scaffoldFinderLight, findsOneWidget);

        await themeProvider.setThemeMode(ThemeMode.dark);
        await tester.pump();
        await pumpAndSettleWithTimeout(tester);

        final scaffoldFinderDark = find.byType(Scaffold);
        expect(scaffoldFinderDark, findsOneWidget);
      },
    );
  });
}
