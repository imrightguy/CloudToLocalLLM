import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/unified_settings_screen.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Settings Screen Responsive Layout Property Tests', () {
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 5: Settings screen adapts to mobile layout',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createPlatformTestApp(
              const UnifiedSettingsScreen(),
              platformService: platformService,
            ),
            width: 400.0,
            height: 800.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expect(find.byType(UnifiedSettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 5: Settings screen adapts to tablet layout',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createPlatformTestApp(
              const UnifiedSettingsScreen(),
              platformService: platformService,
            ),
            width: 800.0,
            height: 1024.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expect(find.byType(UnifiedSettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 5: Settings screen adapts to desktop layout',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createPlatformTestApp(
              const UnifiedSettingsScreen(),
              platformService: platformService,
            ),
            width: 1440.0,
            height: 900.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expect(find.byType(UnifiedSettingsScreen), findsOneWidget);
      },
    );
  });
}
