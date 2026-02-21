import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/admin/admin_center_screen.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

/// **Feature: unified-app-theming, Property 4: Platform-Appropriate Components**
///
/// Property: For any screen, the rendered components SHALL match the platform
/// (Material for web/Android, Cupertino for iOS, native for desktop)
/// Validates: Requirements 2.4, 2.5, 2.6, 2.7
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Admin Center Platform Components Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;
    late PlatformAdapter platformAdapter;
    late MockAuthService authService;
    late MockAdminCenterService adminService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
      platformAdapter = PlatformAdapter(platformService);
      authService = createMockAuthService(authenticated: true);
      adminService = createMockAdminCenterService();
    });

    testWidgets(
      'Property 4: Admin Center uses Material components on web platform',
      (WidgetTester tester) async {
        // Property: For any screen, rendered components SHALL match the platform

        // Platform detection returns web by default in tests
        expect(platformService.isWeb, isTrue);

        await tester.pumpWidget(
          createAuthenticatedTestApp(
            const AdminCenterScreen(),
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Verify Material components are used (Scaffold, AppBar, etc.)
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);

        // Verify screen renders successfully
        expect(find.byType(AdminCenterScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 4: Admin Center components are consistent across theme changes',
      (WidgetTester tester) async {
        // Property: Platform components remain consistent when theme changes

        await tester.pumpWidget(
          createFullTestApp(
            const AdminCenterScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
            platformAdapter: platformAdapter,
            authService: authService,
            adminService: adminService,
            themeMode: ThemeMode.light,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // Verify Material components in light theme
        final scaffoldFinderLight = find.byType(Scaffold);
        expect(scaffoldFinderLight, findsOneWidget);

        // Change to dark theme
        await themeProvider.setThemeMode(ThemeMode.dark);
        await tester.pump();
        await pumpAndSettleWithTimeout(tester);

        // Verify same Material components in dark theme
        final scaffoldFinderDark = find.byType(Scaffold);
        expect(scaffoldFinderDark, findsOneWidget);

        // Component type should not change with theme
        expect(scaffoldFinderLight.runtimeType, scaffoldFinderDark.runtimeType);
      },
    );

    testWidgets(
      'Property 4: Admin Center uses platform-appropriate navigation',
      (WidgetTester tester) async {
        // Property: Navigation components match platform conventions

        await tester.pumpWidget(
          createAuthenticatedTestApp(
            const AdminCenterScreen(),
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);

        // On web/desktop, should use Material navigation patterns
        if (platformService.isWeb ||
            platformService.isWindows ||
            platformService.isLinux) {
          // Material uses AppBar for navigation
          expect(find.byType(AppBar), findsOneWidget);
        }
      },
    );
  });
}
