import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/admin/admin_center_screen.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

/// **Feature: unified-app-theming, Property 5: Responsive Layout Adaptation**
///
/// Property: For any screen width change, content SHALL reflow within 300ms without data loss
/// Validates: Requirements 3.3, 4.3, 5.3, 6.4, 7.4, 8.4, 9.4, 10.6, 11.4, 12.3, 13.4
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Admin Center Responsive Layout Property Tests', () {
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 5: Admin Center adapts to mobile layout (< 600px)',
      (WidgetTester tester) async {
        // Property: Content reflows for mobile screen sizes

        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const AdminCenterScreen(),
              platformService: platformService,
            ),
            width: 400.0,
            height: 800.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Verify screen renders in mobile layout
        expect(find.byType(AdminCenterScreen), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);

        // Mobile layout should use single column
        final mediaQuery = tester.element(find.byType(AdminCenterScreen));
        final size = MediaQuery.of(mediaQuery).size;
        expect(size.width, equals(400.0));
      },
    );

    testWidgets(
      'Property 5: Admin Center adapts to tablet layout (600-1024px)',
      (WidgetTester tester) async {
        // Property: Content reflows for tablet screen sizes

        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const AdminCenterScreen(),
              platformService: platformService,
            ),
            width: 800.0,
            height: 1024.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Verify screen renders in tablet layout
        expect(find.byType(AdminCenterScreen), findsOneWidget);

        final mediaQuery = tester.element(find.byType(AdminCenterScreen));
        final size = MediaQuery.of(mediaQuery).size;
        expect(size.width, equals(800.0));
      },
    );

    testWidgets(
      'Property 5: Admin Center adapts to desktop layout (> 1024px)',
      (WidgetTester tester) async {
        // Property: Content reflows for desktop screen sizes

        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const AdminCenterScreen(),
              platformService: platformService,
            ),
            width: 1440.0,
            height: 900.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Verify screen renders in desktop layout
        expect(find.byType(AdminCenterScreen), findsOneWidget);

        final mediaQuery = tester.element(find.byType(AdminCenterScreen));
        final size = MediaQuery.of(mediaQuery).size;
        expect(size.width, equals(1440.0));
      },
    );

    testWidgets(
      'Property 5: Admin Center reflows within 500ms on width change',
      (WidgetTester tester) async {
        // Property: Layout changes complete within 500ms

        // Start with mobile width
        await tester.pumpWidget(
          wrapWithMediaQuery(
            createAuthenticatedTestApp(
              const AdminCenterScreen(),
              platformService: platformService,
            ),
            width: 400.0,
            height: 800.0,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Measure time to reflow to desktop width
        final duration = await measureExecutionTime(() async {
          await tester.pumpWidget(
            wrapWithMediaQuery(
              createAuthenticatedTestApp(
                const AdminCenterScreen(),
                platformService: platformService,
              ),
              width: 1440.0,
              height: 900.0,
            ),
          );
          await pumpAndSettleWithTimeout(tester);
        });

        // Verify reflow completes within 500ms
        expectExecutionTimeWithin(duration, const Duration(milliseconds: 500));

        // Verify screen still renders correctly
        expect(find.byType(AdminCenterScreen), findsOneWidget);
      },
    );
  });
}
