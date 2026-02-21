/// Property-Based Test for Platform Detection Timing
///
/// **Feature: unified-app-theming, Property 2: Platform Detection Timing**
///
/// Tests that platform detection completes within 100ms during application initialization.
/// This is a critical property for ensuring optimal startup performance.
///
/// **Validates: Requirements 2.1**
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 2: Platform Detection Timing', () {
    /// Property: For any application initialization, platform detection SHALL complete within 100ms
    ///
    /// This test verifies that platform detection completes within the required
    /// 100ms timing constraint during application initialization.
    test('platform detection completes within 100ms on initialization',
        () async {
      final stopwatch = Stopwatch()..start();

      final platformService = PlatformDetectionService();

      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason:
            'Platform detection should complete within 100ms during initialization, but took ${stopwatch.elapsedMilliseconds}ms',
      );

      // Verify platform was detected
      expect(platformService.detectedPlatform, isNotNull);
      expect(platformService.isInitialized, true);

      platformService.dispose();
    });

    /// Property: Multiple sequential platform detections complete within 100ms each
    test('multiple sequential platform detections complete within 100ms each',
        () async {
      const int iterations = 10;
      final timings = <int>[];

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();

        final platformService = PlatformDetectionService();

        stopwatch.stop();
        timings.add(stopwatch.elapsedMilliseconds);

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Iteration $i: Platform detection should complete within 100ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(platformService.detectedPlatform, isNotNull);
        platformService.dispose();
      }

      // Verify all timings are under 100ms
      for (int i = 0; i < timings.length; i++) {
        expect(
          timings[i],
          lessThan(100),
          reason: 'Iteration $i timing ${timings[i]}ms exceeds 100ms threshold',
        );
      }

      // Calculate and verify average timing
      final avgTiming = timings.reduce((a, b) => a + b) / timings.length;
      debugPrint(
        'Average platform detection time across $iterations iterations: ${avgTiming}ms',
      );
    });

    /// Property: Platform detection timing remains consistent under rapid successive calls
    test('platform detection timing remains under 100ms with rapid calls',
        () async {
      const int iterations = 20;
      final timings = <int>[];

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();

        final platformService = PlatformDetectionService();

        stopwatch.stop();
        timings.add(stopwatch.elapsedMilliseconds);

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Rapid call $i: Platform detection should complete within 100ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        platformService.dispose();
      }

      final maxTiming = timings.reduce((a, b) => a > b ? a : b);
      expect(
        maxTiming,
        lessThan(100),
        reason:
            'Maximum timing across rapid calls was $maxTiming ms, exceeds 100ms threshold',
      );

      debugPrint(
        'Maximum platform detection time across $iterations rapid calls: ${maxTiming}ms',
      );
    });

    /// Property: Platform detection timing remains consistent across 100 iterations
    test('platform detection timing remains consistent across 100 iterations',
        () async {
      const int iterations = 100;
      final timings = <int>[];
      int exceedCount = 0;

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();

        final platformService = PlatformDetectionService();

        stopwatch.stop();
        final elapsed = stopwatch.elapsedMilliseconds;
        timings.add(elapsed);

        if (elapsed >= 100) {
          exceedCount++;
        }

        platformService.dispose();
      }

      expect(
        exceedCount,
        0,
        reason:
            '$exceedCount out of $iterations iterations exceeded 100ms threshold',
      );

      final avgTiming = timings.reduce((a, b) => a + b) / timings.length;
      final maxTiming = timings.reduce((a, b) => a > b ? a : b);

      expect(
        maxTiming,
        lessThan(100),
        reason:
            'Maximum timing across 100 iterations was $maxTiming ms, exceeds 100ms threshold',
      );

      expect(
        avgTiming,
        lessThan(50),
        reason:
            'Average timing across 100 iterations was $avgTiming ms, should be well under 100ms',
      );

      debugPrint(
        'Platform detection timing stats over $iterations iterations: avg=${avgTiming}ms, max=${maxTiming}ms',
      );
    });

    /// Property: detectPlatform() method completes within 100ms
    test('detectPlatform() method completes within 100ms', () async {
      final platformService = PlatformDetectionService();

      // Clear cache to force re-detection
      platformService.clearCache();

      final stopwatch = Stopwatch()..start();
      final platform = platformService.detectPlatform();
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason:
            'detectPlatform() should complete within 100ms, but took ${stopwatch.elapsedMilliseconds}ms',
      );

      expect(platform, isNotNull);

      platformService.dispose();
    });

    /// Property: Platform detection with cache clearing completes within 100ms
    test('platform detection with cache clearing completes within 100ms',
        () async {
      final platformService = PlatformDetectionService();

      // Perform multiple detections with cache clearing
      for (int i = 0; i < 10; i++) {
        platformService.clearCache();

        final stopwatch = Stopwatch()..start();
        final platform = platformService.detectPlatform();
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Iteration $i: Platform detection after cache clear should complete within 100ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(platform, isNotNull);
      }

      platformService.dispose();
    });

    /// Property: refreshDetection() completes within 100ms
    test('refreshDetection() completes within 100ms', () async {
      final platformService = PlatformDetectionService();

      final stopwatch = Stopwatch()..start();
      platformService.refreshDetection();
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason:
            'refreshDetection() should complete within 100ms, but took ${stopwatch.elapsedMilliseconds}ms',
      );

      expect(platformService.detectedPlatform, isNotNull);

      platformService.dispose();
    });
  });
}
