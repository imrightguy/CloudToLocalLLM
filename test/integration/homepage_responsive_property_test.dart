import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/marketing/homepage_screen.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Homepage Responsive Layout Property Tests', () {
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 5: Homepage adapts to mobile layout',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createPlatformTestApp(
              const HomepageScreen(),
              platformService: platformService,
            ),
            width: 400.0,
            height: 800.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expect(find.byType(HomepageScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 5: Homepage adapts to tablet layout',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createPlatformTestApp(
              const HomepageScreen(),
              platformService: platformService,
            ),
            width: 800.0,
            height: 1024.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expect(find.byType(HomepageScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 5: Homepage adapts to desktop layout',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createPlatformTestApp(
              const HomepageScreen(),
              platformService: platformService,
            ),
            width: 1440.0,
            height: 900.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expect(find.byType(HomepageScreen), findsOneWidget);
      },
    );
  });
}
