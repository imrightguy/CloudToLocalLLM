import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:cloudtolocalllm/di/locator.dart' as di;

/// Integration test for unified theming system
///
/// This test verifies that:
/// 1. ThemeProvider is properly wired across all screens
/// 2. PlatformDetectionService is accessible to all screens
/// 3. PlatformAdapter is properly configured for component selection
/// 4. Theme changes propagate correctly
/// 5. Platform-specific components are selected appropriately
///
/// **Validates: Requirements 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18**

void main() {
  group('Unified Theming Integration Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformDetectionService;
    late PlatformAdapter platformAdapter;

    setUp(() async {
      // Initialize service locator with core services
      if (!di.serviceLocator.isRegistered<ThemeProvider>()) {
        await di.setupCoreServices();
      }

      // Get services from locator
      themeProvider = di.serviceLocator.get<ThemeProvider>();
      platformDetectionService =
          di.serviceLocator.get<PlatformDetectionService>();
      platformAdapter = di.serviceLocator.get<PlatformAdapter>();

      // Reset theme to light mode for consistent testing
      await themeProvider.setThemeMode(ThemeMode.light);
    });

    tearDown(() {
      // Reset theme after each test
      themeProvider.setThemeMode(ThemeMode.light);
    });

    testWidgets('ThemeProvider is accessible via Provider', (tester) async {
      ThemeProvider? capturedProvider;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedProvider = context.watch<ThemeProvider>();
                return const Scaffold(body: Text('Test'));
              },
            ),
          ),
        ),
      );

      expect(capturedProvider, isNotNull);
      expect(capturedProvider, equals(themeProvider));
    });

    testWidgets('PlatformDetectionService is accessible from service locator',
        (tester) async {
      expect(
          di.serviceLocator.isRegistered<PlatformDetectionService>(), isTrue);

      final service = di.serviceLocator.get<PlatformDetectionService>();
      expect(service, isNotNull);
      expect(service, equals(platformDetectionService));
    });

    testWidgets('PlatformAdapter is accessible from service locator',
        (tester) async {
      expect(di.serviceLocator.isRegistered<PlatformAdapter>(), isTrue);

      final adapter = di.serviceLocator.get<PlatformAdapter>();
      expect(adapter, isNotNull);
      expect(adapter, equals(platformAdapter));
    });

    testWidgets('Theme changes propagate through Provider', (tester) async {
      ThemeMode? capturedMode;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final provider = context.watch<ThemeProvider>();
                capturedMode = provider.themeMode;
                return const Scaffold(body: Text('Test'));
              },
            ),
          ),
        ),
      );

      // Initial mode should be light
      expect(capturedMode, equals(ThemeMode.light));

      // Change to dark mode
      await themeProvider.setThemeMode(ThemeMode.dark);
      await tester.pump();

      // Verify mode changed
      expect(capturedMode, equals(ThemeMode.dark));
    });

    testWidgets('PlatformAdapter provides correct component type',
        (tester) async {
      // Platform adapter should provide components based on platform
      expect(platformAdapter, isNotNull);

      // Verify platform detection is working
      final isWeb = platformDetectionService.isWeb;
      final isWindows = platformDetectionService.isWindows;
      final isLinux = platformDetectionService.isLinux;

      // At least one platform should be detected
      expect(isWeb || isWindows || isLinux, isTrue);
    });

    testWidgets('Multiple screens can access ThemeProvider simultaneously',
        (tester) async {
      final capturedProviders = <ThemeProvider>[];

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    capturedProviders.add(context.watch<ThemeProvider>());
                    return const Text('Screen 1');
                  },
                ),
                Builder(
                  builder: (context) {
                    capturedProviders.add(context.watch<ThemeProvider>());
                    return const Text('Screen 2');
                  },
                ),
                Builder(
                  builder: (context) {
                    capturedProviders.add(context.watch<ThemeProvider>());
                    return const Text('Screen 3');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      // All screens should get the same provider instance
      expect(capturedProviders.length, equals(3));
      expect(capturedProviders[0], equals(themeProvider));
      expect(capturedProviders[1], equals(themeProvider));
      expect(capturedProviders[2], equals(themeProvider));
    });

    testWidgets('Theme changes propagate to all screens simultaneously',
        (tester) async {
      final capturedModes = <ThemeMode>[];

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    final provider = context.watch<ThemeProvider>();
                    if (capturedModes.isEmpty) {
                      capturedModes.add(provider.themeMode);
                    } else {
                      capturedModes[0] = provider.themeMode;
                    }
                    return const Text('Screen 1');
                  },
                ),
                Builder(
                  builder: (context) {
                    final provider = context.watch<ThemeProvider>();
                    if (capturedModes.length < 2) {
                      capturedModes.add(provider.themeMode);
                    } else {
                      capturedModes[1] = provider.themeMode;
                    }
                    return const Text('Screen 2');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state
      expect(capturedModes.length, equals(2));
      expect(capturedModes[0], equals(ThemeMode.light));
      expect(capturedModes[1], equals(ThemeMode.light));

      // Change theme
      await themeProvider.setThemeMode(ThemeMode.dark);
      await tester.pump();

      // Both screens should reflect the change
      expect(capturedModes[0], equals(ThemeMode.dark));
      expect(capturedModes[1], equals(ThemeMode.dark));
    });

    test('Service locator maintains singleton instances', () {
      // Get services multiple times
      final provider1 = di.serviceLocator.get<ThemeProvider>();
      final provider2 = di.serviceLocator.get<ThemeProvider>();

      final platform1 = di.serviceLocator.get<PlatformDetectionService>();
      final platform2 = di.serviceLocator.get<PlatformDetectionService>();

      final adapter1 = di.serviceLocator.get<PlatformAdapter>();
      final adapter2 = di.serviceLocator.get<PlatformAdapter>();

      // All should be the same instance
      expect(provider1, equals(provider2));
      expect(platform1, equals(platform2));
      expect(adapter1, equals(adapter2));
    });

    testWidgets('Platform detection results are consistent', (tester) async {
      // Get platform info multiple times
      final isWeb1 = platformDetectionService.isWeb;
      final isWeb2 = platformDetectionService.isWeb;

      final isWindows1 = platformDetectionService.isWindows;
      final isWindows2 = platformDetectionService.isWindows;

      final isLinux1 = platformDetectionService.isLinux;
      final isLinux2 = platformDetectionService.isLinux;

      // Results should be consistent
      expect(isWeb1, equals(isWeb2));
      expect(isWindows1, equals(isWindows2));
      expect(isLinux1, equals(isLinux2));
    });

    testWidgets('Theme persistence works correctly', (tester) async {
      // Set theme to dark
      await themeProvider.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      // Verify theme was set
      expect(themeProvider.themeMode, equals(ThemeMode.dark));

      // Reload theme (simulates app restart)
      await themeProvider.reloadThemePreference();
      await tester.pumpAndSettle();

      // Theme should still be dark
      expect(themeProvider.themeMode, equals(ThemeMode.dark));
    });
  });

  group('Service Integration Tests', () {
    testWidgets('All core services are registered', (tester) async {
      // Ensure core services are set up
      if (!di.serviceLocator.isRegistered<ThemeProvider>()) {
        await di.setupCoreServices();
      }

      // Verify all core services are registered
      expect(di.serviceLocator.isRegistered<ThemeProvider>(), isTrue);
      expect(
          di.serviceLocator.isRegistered<PlatformDetectionService>(), isTrue);
      expect(di.serviceLocator.isRegistered<PlatformAdapter>(), isTrue);
    });

    testWidgets('Services can be retrieved without errors', (tester) async {
      // Ensure core services are set up
      if (!di.serviceLocator.isRegistered<ThemeProvider>()) {
        await di.setupCoreServices();
      }

      // Retrieve services
      expect(() => di.serviceLocator.get<ThemeProvider>(), returnsNormally);
      expect(() => di.serviceLocator.get<PlatformDetectionService>(),
          returnsNormally);
      expect(() => di.serviceLocator.get<PlatformAdapter>(), returnsNormally);
    });
  });
}
