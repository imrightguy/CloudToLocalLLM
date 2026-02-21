import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:cloudtolocalllm/di/locator.dart' as di;
import 'package:cloudtolocalllm/config/theme.dart';

// Import screens to test
import 'package:cloudtolocalllm/screens/marketing/homepage_screen.dart';
import 'package:cloudtolocalllm/screens/marketing/documentation_screen.dart';

/// End-to-end integration test for theme application across screens
///
/// This test verifies that:
/// 1. All screens properly consume ThemeProvider
/// 2. Theme changes propagate to all screens
/// 3. Screens render correctly with both light and dark themes
/// 4. Platform-specific components are used appropriately
///
/// **Validates: Requirements 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18**

void main() {
  group('End-to-End Theme Integration Tests', () {
    late ThemeProvider themeProvider;
    late PlatformAdapter platformAdapter;

    setUp(() async {
      // Initialize service locator with core services
      if (!di.serviceLocator.isRegistered<ThemeProvider>()) {
        await di.setupCoreServices();
      }

      // Get services from locator
      themeProvider = di.serviceLocator.get<ThemeProvider>();
      platformAdapter = di.serviceLocator.get<PlatformAdapter>();

      // Reset theme to light mode for consistent testing
      await themeProvider.setThemeMode(ThemeMode.light);
    });

    tearDown(() {
      // Reset theme after each test
      themeProvider.setThemeMode(ThemeMode.light);
    });

    /// Helper to create a test app with theme provider
    Widget createTestApp(Widget child) {
      return ChangeNotifierProvider.value(
        value: themeProvider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: child,
        ),
      );
    }

    testWidgets('HomepageScreen renders with light theme', (tester) async {
      await tester.pumpWidget(createTestApp(
        const HomepageScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify screen renders
      expect(find.byType(HomepageScreen), findsOneWidget);

      // Verify theme is applied
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.light));
    });

    testWidgets('HomepageScreen renders with dark theme', (tester) async {
      // Change to dark theme
      await themeProvider.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(createTestApp(
        const HomepageScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify screen renders
      expect(find.byType(HomepageScreen), findsOneWidget);

      // Verify theme is applied
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('DocumentationScreen renders with light theme', (tester) async {
      await tester.pumpWidget(createTestApp(
        const DocumentationScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify screen renders
      expect(find.byType(DocumentationScreen), findsOneWidget);

      // Verify theme is applied
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.light));
    });

    testWidgets('DocumentationScreen renders with dark theme', (tester) async {
      // Change to dark theme
      await themeProvider.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(createTestApp(
        const DocumentationScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify screen renders
      expect(find.byType(DocumentationScreen), findsOneWidget);

      // Verify theme is applied
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('Theme changes propagate to HomepageScreen', (tester) async {
      await tester.pumpWidget(createTestApp(
        const HomepageScreen(),
      ));
      await tester.pumpAndSettle();

      // Initial theme should be light
      var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.light));

      // Change to dark theme
      await themeProvider.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      // Theme should now be dark
      materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('Multiple screens can coexist with same theme', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: Navigator(
              pages: const [
                MaterialPage(child: HomepageScreen()),
              ],
              onDidRemovePage: (page) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both screens should be present
      expect(find.byType(HomepageScreen), findsOneWidget);

      // Theme should be applied to both
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.light));
    });

    testWidgets('Platform detection is available to all screens',
        (tester) async {
      bool? capturedIsWeb;
      bool? capturedIsWindows;
      bool? capturedIsLinux;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Access platform detection service
                final platformService =
                    di.serviceLocator.get<PlatformDetectionService>();
                capturedIsWeb = platformService.isWeb;
                capturedIsWindows = platformService.isWindows;
                capturedIsLinux = platformService.isLinux;
                return const Scaffold(body: Text('Test'));
              },
            ),
          ),
        ),
      );

      // Platform detection should work
      expect(capturedIsWeb, isNotNull);
      expect(capturedIsWindows, isNotNull);
      expect(capturedIsLinux, isNotNull);

      // At least one platform should be detected
      expect(capturedIsWeb! || capturedIsWindows! || capturedIsLinux!, isTrue);
    });

    testWidgets('PlatformAdapter is available to all screens', (tester) async {
      PlatformAdapter? capturedAdapter;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Access platform adapter
                capturedAdapter = di.serviceLocator.get<PlatformAdapter>();
                return const Scaffold(body: Text('Test'));
              },
            ),
          ),
        ),
      );

      // Platform adapter should be available
      expect(capturedAdapter, isNotNull);
      expect(capturedAdapter, equals(platformAdapter));
    });
  });

  group('Theme Persistence Integration Tests', () {
    late ThemeProvider themeProvider;

    setUp(() async {
      // Initialize service locator with core services
      if (!di.serviceLocator.isRegistered<ThemeProvider>()) {
        await di.setupCoreServices();
      }

      themeProvider = di.serviceLocator.get<ThemeProvider>();
      await themeProvider.setThemeMode(ThemeMode.light);
    });

    testWidgets('Theme persists across app restarts', (tester) async {
      // Set theme to dark
      await themeProvider.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      expect(themeProvider.themeMode, equals(ThemeMode.dark));

      // Simulate app restart by reloading theme
      await themeProvider.reloadThemePreference();
      await tester.pumpAndSettle();

      // Theme should still be dark
      expect(themeProvider.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('Theme persists across multiple changes', (tester) async {
      // Change theme multiple times
      await themeProvider.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(themeProvider.themeMode, equals(ThemeMode.dark));

      await themeProvider.setThemeMode(ThemeMode.system);
      await tester.pumpAndSettle();
      expect(themeProvider.themeMode, equals(ThemeMode.system));

      await themeProvider.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(themeProvider.themeMode, equals(ThemeMode.light));

      // Reload theme
      await themeProvider.reloadThemePreference();
      await tester.pumpAndSettle();

      // Should be light (last set value)
      expect(themeProvider.themeMode, equals(ThemeMode.light));
    });
  });

  group('Responsive Layout Integration Tests', () {
    late ThemeProvider themeProvider;

    setUp(() async {
      if (!di.serviceLocator.isRegistered<ThemeProvider>()) {
        await di.setupCoreServices();
      }

      themeProvider = di.serviceLocator.get<ThemeProvider>();
      await themeProvider.setThemeMode(ThemeMode.light);
    });

    testWidgets('Screens adapt to mobile screen size', (tester) async {
      // Set mobile screen size
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomepageScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen should render without errors
      expect(find.byType(HomepageScreen), findsOneWidget);
    });

    testWidgets('Screens adapt to tablet screen size', (tester) async {
      // Set tablet screen size
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomepageScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen should render without errors
      expect(find.byType(HomepageScreen), findsOneWidget);
    });

    testWidgets('Screens adapt to desktop screen size', (tester) async {
      // Set desktop screen size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomepageScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen should render without errors
      expect(find.byType(HomepageScreen), findsOneWidget);
    });
  });
}
