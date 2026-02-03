/// Property-Based Test for Platform Detection Caching
///
/// **Feature: unified-app-theming, Property 15: Platform Detection Caching**
///
/// Tests that platform detection lookups return cached values within 50ms.
/// This is a critical property for ensuring optimal performance
/// across the application.
///
/// **Validates: Requirements 18.4**
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/models/platform_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 15: Platform Detection Caching', () {
    late PlatformDetectionService platformService;

    setUp(() {
      platformService = PlatformDetectionService();
      // Wait for initial detection
    });

    tearDown(() {
      platformService.dispose();
    });

    /// Property: For any platform detection lookup, cached values SHALL be returned within 50ms
    ///
    /// This test verifies that when platform detection is cached, subsequent lookups
    /// return the cached value within the required 50ms timeframe.
    test('cached platform detection lookups complete within 50ms', () async {
      // Perform initial detection
      final initialPlatform = platformService.detectPlatform();
      expect(initialPlatform, isNotNull);

      // Perform multiple cached lookups and measure timing
      final timings = <int>[];
      for (int i = 0; i < 10; i++) {
        final startTime = DateTime.now();
        final platform = platformService.detectPlatform();
        final elapsed = DateTime.now().difference(startTime).inMicroseconds;

        expect(platform, initialPlatform);
        timings.add(elapsed);
      }

      // All lookups should be extremely fast (well under 50ms = 50000 microseconds)
      for (int i = 0; i < timings.length; i++) {
        expect(
          timings[i],
          lessThan(50000),
          reason:
              'Cached platform detection $i should complete within 50ms (actual: ${timings[i] / 1000}ms)',
        );
      }

      // Average should be very fast
      final avgMicroseconds = timings.reduce((a, b) => a + b) / timings.length;
      debugPrint(
        'Average cached platform detection time: ${avgMicroseconds / 1000}ms',
      );
    });

    /// Property: Platform detection cache should remain valid for configured duration
    test('platform detection cache remains valid for configured duration',
        () async {
      // Perform initial detection
      final initialPlatform = platformService.detectPlatform();

      // Cache should be valid immediately
      expect(platformService.detectedPlatform, initialPlatform);

      // Cache should still be valid after a short delay (under 5 minutes)
      await Future.delayed(const Duration(seconds: 1));
      final cachedPlatform = platformService.detectPlatform();
      expect(cachedPlatform, initialPlatform);

      // Verify it's using cache (should be instant)
      final startTime = DateTime.now();
      platformService.detectPlatform();
      final elapsed = DateTime.now().difference(startTime).inMicroseconds;

      expect(
        elapsed,
        lessThan(50000),
        reason:
            'Cached detection should be instant (actual: ${elapsed / 1000}ms)',
      );
    });

    /// Property: Platform info cache should return quickly
    test('platform info cache returns within 50ms', () async {
      // Get initial platform info
      final info1 = platformService.getDetectionInfo();
      expect(info1, isNotEmpty);

      // Subsequent calls should use cache
      final timings = <int>[];
      for (int i = 0; i < 10; i++) {
        final startTime = DateTime.now();
        final info = platformService.getDetectionInfo();
        final elapsed = DateTime.now().difference(startTime).inMicroseconds;

        expect(info, isNotEmpty);
        timings.add(elapsed);
      }

      // All lookups should be fast
      for (int i = 0; i < timings.length; i++) {
        expect(
          timings[i],
          lessThan(50000),
          reason:
              'Cached platform info lookup $i should complete within 50ms (actual: ${timings[i] / 1000}ms)',
        );
      }
    });

    /// Property: Cache clearing should force re-detection
    test('cache clearing forces re-detection', () async {
      // Perform initial detection
      final initialPlatform = platformService.detectPlatform();
      expect(initialPlatform, isNotNull);

      // Clear cache
      platformService.clearCache();

      // Next detection should work (may take longer as it re-detects)
      final startTime = DateTime.now();
      final newPlatform = platformService.detectPlatform();
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      expect(newPlatform, initialPlatform);
      // Should still complete within 100ms (requirement 2.1)
      expect(
        elapsed,
        lessThan(100),
        reason:
            'Re-detection after cache clear should complete within 100ms (actual: ${elapsed}ms)',
      );
    });

    /// Property: Multiple rapid platform lookups should use cache efficiently
    test('rapid platform lookups use cache efficiently', () async {
      // Perform initial detection
      platformService.detectPlatform();

      // Perform many rapid lookups
      final startTime = DateTime.now();
      for (int i = 0; i < 100; i++) {
        final platform = platformService.currentPlatform;
        expect(platform, isNotNull);
      }
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      // 100 lookups should complete very quickly (well under 50ms total)
      expect(
        elapsed,
        lessThan(50),
        reason:
            '100 cached platform lookups should complete within 50ms (actual: ${elapsed}ms)',
      );

      debugPrint('100 cached platform lookups completed in ${elapsed}ms');
    });

    /// Property: Platform config lookups should use cache
    test('platform config lookups use cache efficiently', () async {
      // Get initial config
      final config1 = platformService.getPlatformConfig();
      expect(config1, isNotNull);

      // Perform multiple cached lookups
      final timings = <int>[];
      for (int i = 0; i < 10; i++) {
        final startTime = DateTime.now();
        final config = platformService.getPlatformConfig();
        final elapsed = DateTime.now().difference(startTime).inMicroseconds;

        expect(config, isNotNull);
        timings.add(elapsed);
      }

      // All lookups should be fast
      for (int i = 0; i < timings.length; i++) {
        expect(
          timings[i],
          lessThan(50000),
          reason:
              'Cached config lookup $i should complete within 50ms (actual: ${timings[i] / 1000}ms)',
        );
      }
    });

    /// Property: Download options lookups should use cache
    test('download options lookups use cache efficiently', () async {
      // Get initial download options
      final options1 = platformService.getDownloadOptions();
      expect(options1, isNotEmpty);

      // Perform multiple cached lookups
      final timings = <int>[];
      for (int i = 0; i < 10; i++) {
        final startTime = DateTime.now();
        final options = platformService.getDownloadOptions();
        final elapsed = DateTime.now().difference(startTime).inMicroseconds;

        expect(options, isNotEmpty);
        timings.add(elapsed);
      }

      // All lookups should be fast
      for (int i = 0; i < timings.length; i++) {
        expect(
          timings[i],
          lessThan(50000),
          reason:
              'Cached download options lookup $i should complete within 50ms (actual: ${timings[i] / 1000}ms)',
        );
      }
    });

    /// Property: Platform detection should be consistent across multiple calls
    test('platform detection is consistent across multiple calls', () async {
      // Perform multiple detections
      final platforms = <PlatformType>[];
      for (int i = 0; i < 10; i++) {
        platforms.add(platformService.detectPlatform());
      }

      // All detections should return the same platform
      final firstPlatform = platforms.first;
      for (int i = 1; i < platforms.length; i++) {
        expect(
          platforms[i],
          firstPlatform,
          reason: 'Platform detection should be consistent (call $i)',
        );
      }
    });

    /// Property: Refresh detection should update cache
    test('refresh detection updates cache', () async {
      // Perform initial detection
      final initialPlatform = platformService.detectPlatform();

      // Refresh detection
      platformService.refreshDetection();

      // Should still return same platform (but cache is refreshed)
      final refreshedPlatform = platformService.detectPlatform();
      expect(refreshedPlatform, initialPlatform);

      // Subsequent lookups should be fast (using new cache)
      final startTime = DateTime.now();
      for (int i = 0; i < 10; i++) {
        platformService.detectPlatform();
      }
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      expect(
        elapsed,
        lessThan(50),
        reason:
            'Cached lookups after refresh should be fast (actual: ${elapsed}ms)',
      );
    });

    /// Property: Platform-specific checks should use cache
    test('platform-specific checks use cache efficiently', () async {
      // Perform initial detection
      platformService.detectPlatform();

      // Perform multiple platform checks
      final startTime = DateTime.now();
      for (int i = 0; i < 100; i++) {
        platformService.isWeb;
        platformService.isWindows;
        platformService.isLinux;
        platformService.isMacOS;
        platformService.isDesktop;
        platformService.isMobile;
      }
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      // 600 checks (100 iterations × 6 checks) should complete very quickly
      expect(
        elapsed,
        lessThan(50),
        reason:
            '600 cached platform checks should complete within 50ms (actual: ${elapsed}ms)',
      );

      debugPrint('600 cached platform checks completed in ${elapsed}ms');
    });
  });
}
