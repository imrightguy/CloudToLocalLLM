import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/admin/admin_center_screen.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

/// **Feature: unified-app-theming, Property 1: Theme Application Timing**
///
/// Property: For any theme change, all screens SHALL update within 200 milliseconds
/// Validates: Requirements 1.2, 4.7, 5.7, 6.6, 7.6, 8.5, 9.5, 10.7, 11.5, 12.5
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Admin Center Theme Application Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;
    late MockAuthService authService;
    late MockAdminCenterService adminService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
      authService = createMockAuthService(authenticated: true);
      adminService = createMockAdminCenterService();
    });

    testWidgets(
      'Property 1: Admin Center applies light theme correctly',
      (WidgetTester tester) async {
        // Property: Theme application is correct

        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const AdminCenterScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
            authService: authService,
            adminService: adminService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Verify light theme is applied
        expectThemeMode(tester, Brightness.light);
        expect(find.byType(AdminCenterScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Admin Center applies dark theme correctly',
      (WidgetTester tester) async {
        // Property: Theme application is correct

        await themeProvider.setThemeMode(ThemeMode.dark);

        await tester.pumpWidget(
          createFullTestApp(
            const AdminCenterScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
            authService: authService,
            adminService: adminService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Verify dark theme is applied
        expectThemeMode(tester, Brightness.dark);
        expect(find.byType(AdminCenterScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Admin Center updates theme within 200ms',
      (WidgetTester tester) async {
        // Property: Theme changes complete within 200ms

        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const AdminCenterScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
            authService: authService,
            adminService: adminService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Measure time to change theme
        final duration = await measureExecutionTime(() async {
          await themeProvider.setThemeMode(ThemeMode.dark);
          await tester.pump();
          await pumpAndSettleWithTimeout(tester);
        });

        // Verify theme change completes within 200ms
        expectExecutionTimeWithin(duration, const Duration(milliseconds: 200));

        // Verify dark theme is now applied
        expectThemeMode(tester, Brightness.dark);
      },
    );

    testWidgets(
      'Property 1: Admin Center handles rapid theme changes',
      (WidgetTester tester) async {
        // Property: Multiple rapid theme changes are handled correctly

        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const AdminCenterScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
            authService: authService,
            adminService: adminService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Perform rapid theme changes
        await themeProvider.setThemeMode(ThemeMode.dark);
        await tester.pump();
        await themeProvider.setThemeMode(ThemeMode.light);
        await tester.pump();
        await themeProvider.setThemeMode(ThemeMode.dark);
        await tester.pump();

        await pumpAndSettleWithTimeout(tester);

        // Verify final theme is applied correctly
        expectThemeMode(tester, Brightness.dark);
        expect(find.byType(AdminCenterScreen), findsOneWidget);
      },
    );
  });
}
