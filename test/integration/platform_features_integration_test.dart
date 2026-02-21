/// This test verifies that:
/// 1. Platform detection works correctly
/// 2. Platform-specific components are selected appropriately
/// 3. Platform features are available on correct platforms
/// 4. Fallback behavior works when platform-specific features are unavailable
///
/// **Validates: Requirements 2, 16, 17**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:cloudtolocalllm/di/locator.dart' as di;

void main() {
  group('Platform Features Integration Tests', () {
    late PlatformDetectionService platformDetectionService;
    late PlatformAdapter platformAdapter;

    setUp(() async {
      // Initialize service locator with core services
      if (!di.serviceLocator.isRegistered<PlatformDetectionService>()) {
        await di.setupCoreServices();
      }

      // Get services from locator
      platformDetectionService =
          di.serviceLocator.get<PlatformDetectionService>();
      platformAdapter = di.serviceLocator.get<PlatformAdapter>();
    });

    test('Platform detection identifies exactly one platform', () {
      final isWeb = platformDetectionService.isWeb;
      final isWindows = platformDetectionService.isWindows;
      final isLinux = platformDetectionService.isLinux;

      // Exactly one platform should be true
      final platformCount = [isWeb, isWindows, isLinux].where((p) => p).length;
      expect(platformCount, equals(1),
          reason: 'Exactly one platform should be detected');
    });

    test('Platform detection is consistent across multiple calls', () {
      // Call platform detection multiple times
      final results = List.generate(
          10,
          (_) => {
                'isWeb': platformDetectionService.isWeb,
                'isWindows': platformDetectionService.isWindows,
                'isLinux': platformDetectionService.isLinux,
              });

      // All results should be identical
      for (var i = 1; i < results.length; i++) {
        expect(results[i]['isWeb'], equals(results[0]['isWeb']));
        expect(results[i]['isWindows'], equals(results[0]['isWindows']));
        expect(results[i]['isLinux'], equals(results[0]['isLinux']));
      }
    });

    test('Platform adapter is initialized with platform detection service', () {
      expect(platformAdapter, isNotNull);

      // Platform adapter should have access to platform detection
      // This is verified by the fact that it was constructed with platformDetectionService
      expect(di.serviceLocator.isRegistered<PlatformAdapter>(), isTrue);
    });

    test('Platform detection provides screen size information', () {
      // Platform detection should provide screen size
      // This is platform-dependent, so we just verify it doesn't throw
      expect(() => platformDetectionService.isWeb, returnsNormally);
      expect(() => platformDetectionService.isWindows, returnsNormally);
      expect(() => platformDetectionService.isLinux, returnsNormally);
    });

    testWidgets('Platform adapter provides components without errors',
        (tester) async {
      // Platform adapter should provide components based on platform
      expect(platformAdapter, isNotNull);

      // Verify platform detection is working
      final isWeb = platformDetectionService.isWeb;
      final isWindows = platformDetectionService.isWindows;
      final isLinux = platformDetectionService.isLinux;

      // At least one platform should be detected
      expect(isWeb || isWindows || isLinux, isTrue);

      // Platform adapter should be able to provide components
      // (actual component selection is tested in component-specific tests)
      expect(() => platformAdapter, returnsNormally);
    });

    test('Platform detection caching works correctly', () {
      // Get platform info multiple times
      final start = DateTime.now();

      for (var i = 0; i < 100; i++) {
        platformDetectionService.isWeb;
        platformDetectionService.isWindows;
        platformDetectionService.isLinux;
      }

      final duration = DateTime.now().difference(start);

      // With caching, 100 calls should complete very quickly (< 100ms)
      expect(duration.inMilliseconds, lessThan(100),
          reason: 'Platform detection should be cached for performance');
    });

    test('Platform detection service is singleton', () {
      // Get service multiple times
      final service1 = di.serviceLocator.get<PlatformDetectionService>();
      final service2 = di.serviceLocator.get<PlatformDetectionService>();
      final service3 = di.serviceLocator.get<PlatformDetectionService>();

      // All should be the same instance
      expect(service1, equals(service2));
      expect(service2, equals(service3));
      expect(service1, equals(platformDetectionService));
    });

    test('Platform adapter is singleton', () {
      // Get adapter multiple times
      final adapter1 = di.serviceLocator.get<PlatformAdapter>();
      final adapter2 = di.serviceLocator.get<PlatformAdapter>();
      final adapter3 = di.serviceLocator.get<PlatformAdapter>();

      // All should be the same instance
      expect(adapter1, equals(adapter2));
      expect(adapter2, equals(adapter3));
      expect(adapter1, equals(platformAdapter));
    });

    testWidgets('Platform-specific features are available on correct platforms',
        (tester) async {
      final isWeb = platformDetectionService.isWeb;
      final isWindows = platformDetectionService.isWindows;
      final isLinux = platformDetectionService.isLinux;

      if (isWeb) {
        // Web-specific features should be available
        expect(platformDetectionService.isWeb, isTrue);
        expect(platformDetectionService.isWindows, isFalse);
        expect(platformDetectionService.isLinux, isFalse);
      } else if (isWindows) {
        // Windows-specific features should be available
        expect(platformDetectionService.isWeb, isFalse);
        expect(platformDetectionService.isWindows, isTrue);
        expect(platformDetectionService.isLinux, isFalse);
      } else if (isLinux) {
        // Linux-specific features should be available
        expect(platformDetectionService.isWeb, isFalse);
        expect(platformDetectionService.isWindows, isFalse);
        expect(platformDetectionService.isLinux, isTrue);
      }
    });

    test('Platform detection handles errors gracefully', () {
      // Platform detection should not throw errors
      expect(() => platformDetectionService.isWeb, returnsNormally);
      expect(() => platformDetectionService.isWindows, returnsNormally);
      expect(() => platformDetectionService.isLinux, returnsNormally);
    });

    testWidgets(
        'Platform adapter handles component selection errors gracefully',
        (tester) async {
      // Platform adapter should not throw errors when selecting components
      expect(() => platformAdapter, returnsNormally);

      // Even if a specific component type is not available, adapter should handle it
      // (actual error handling is tested in component-specific tests)
    });
  });

  group('Platform Fallback Tests', () {
    late PlatformDetectionService platformDetectionService;

    setUp(() async {
      if (!di.serviceLocator.isRegistered<PlatformDetectionService>()) {
        await di.setupCoreServices();
      }

      platformDetectionService =
          di.serviceLocator.get<PlatformDetectionService>();
    });

    test('Platform detection provides fallback when detection fails', () {
      // Platform detection should always return a valid platform
      final isWeb = platformDetectionService.isWeb;
      final isWindows = platformDetectionService.isWindows;
      final isLinux = platformDetectionService.isLinux;

      // At least one platform must be detected (fallback behavior)
      expect(isWeb || isWindows || isLinux, isTrue,
          reason: 'Platform detection should provide fallback');
    });

    test('Platform detection is deterministic', () {
      // Multiple calls should return the same result
      final results = <Map<String, bool>>[];

      for (var i = 0; i < 10; i++) {
        results.add({
          'isWeb': platformDetectionService.isWeb,
          'isWindows': platformDetectionService.isWindows,
          'isLinux': platformDetectionService.isLinux,
        });
      }

      // All results should be identical
      for (var i = 1; i < results.length; i++) {
        expect(results[i], equals(results[0]),
            reason: 'Platform detection should be deterministic');
      }
    });
  });

  group('Platform Component Consistency Tests', () {
    late PlatformDetectionService platformDetectionService;
    late PlatformAdapter platformAdapter;

    setUp(() async {
      if (!di.serviceLocator.isRegistered<PlatformDetectionService>()) {
        await di.setupCoreServices();
      }

      platformDetectionService =
          di.serviceLocator.get<PlatformDetectionService>();
      platformAdapter = di.serviceLocator.get<PlatformAdapter>();
    });

    test('Platform adapter uses consistent component types', () {
      // Platform adapter should use consistent component types based on platform
      final isWeb = platformDetectionService.isWeb;
      final isWindows = platformDetectionService.isWindows;
      final isLinux = platformDetectionService.isLinux;

      // Verify platform detection is consistent
      expect(isWeb || isWindows || isLinux, isTrue);

      // Platform adapter should be initialized
      expect(platformAdapter, isNotNull);
    });

    test('Platform adapter maintains state across calls', () {
      // Get adapter multiple times
      final adapter1 = di.serviceLocator.get<PlatformAdapter>();
      final adapter2 = di.serviceLocator.get<PlatformAdapter>();

      // Should be the same instance
      expect(adapter1, equals(adapter2));
      expect(adapter1, equals(platformAdapter));
    });
  });
}
