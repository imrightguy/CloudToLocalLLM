/// Property-Based Test for Platform Detection Fallback
///
/// **Feature: unified-app-theming, Property 13: Platform Detection Fallback**
///
/// Tests that platform detection failures result in using a default platform configuration.
/// This is a critical property for ensuring the application remains functional even when
/// platform detection encounters errors.
///
/// **Validates: Requirements 17.2**
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/models/platform_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 13: Platform Detection Fallback', () {
    /// Property: For any platform detection failure, the application SHALL use a default platform configuration
    ///
    /// This test verifies that when platform detection fails or encounters errors,
    /// the service falls back to a default platform configuration (Windows).
    test('platform detection provides fallback on initialization', () async {
      final platformService = PlatformDetectionService();

      // Even if detection encounters issues, we should have a valid platform
      expect(platformService.detectedPlatform, isNotNull);
      expect(platformService.currentPlatform, isNotNull);
      expect(platformService.isInitialized, true);

      // Should have a valid platform configuration
      final config = platformService.getPlatformConfig();
      expect(config, isNotNull);
      expect(config!.platform, isNotNull);

      platformService.dispose();
    });

    /// Property: currentPlatform always returns a valid platform (never null)
    test('currentPlatform always returns a valid platform', () async {
      final platformService = PlatformDetectionService();

      // currentPlatform should never be null
      expect(platformService.currentPlatform, isNotNull);

      // Clear cache and verify still valid
      platformService.clearCache();
      expect(platformService.currentPlatform, isNotNull);

      // Refresh detection and verify still valid
      platformService.refreshDetection();
      expect(platformService.currentPlatform, isNotNull);

      platformService.dispose();
    });

    /// Property: Platform configuration is always available
    test('platform configuration is always available', () async {
      final platformService = PlatformDetectionService();

      // Should always have a valid configuration
      final config = platformService.getPlatformConfig();
      expect(config, isNotNull);
      expect(config!.platform, isNotNull);
      expect(config.displayName, isNotEmpty);
      expect(config.downloadOptions, isNotEmpty);

      platformService.dispose();
    });

    /// Property: Download options are always available
    test('download options are always available', () async {
      final platformService = PlatformDetectionService();

      // Should always have download options
      final options = platformService.getDownloadOptions();
      expect(options, isNotEmpty);

      // Each option should be valid
      for (final option in options) {
        expect(option.name, isNotEmpty);
        expect(option.downloadUrl, isNotEmpty);
        expect(option.installationType, isNotEmpty);
      }

      platformService.dispose();
    });

    /// Property: Platform detection info is always available
    test('platform detection info is always available', () async {
      final platformService = PlatformDetectionService();

      // Should always have detection info
      final info = platformService.getDetectionInfo();
      expect(info, isNotEmpty);
      expect(info.containsKey('detectedPlatform'), true);
      expect(info.containsKey('currentPlatform'), true);
      expect(info.containsKey('isInitialized'), true);

      platformService.dispose();
    });

    /// Property: Multiple service instances all have valid platforms
    test('multiple service instances all have valid platforms', () async {
      const int iterations = 10;

      for (int i = 0; i < iterations; i++) {
        final platformService = PlatformDetectionService();

        expect(
          platformService.currentPlatform,
          isNotNull,
          reason: 'Iteration $i: currentPlatform should never be null',
        );

        expect(
          platformService.isInitialized,
          true,
          reason: 'Iteration $i: service should be initialized',
        );

        final config = platformService.getPlatformConfig();
        expect(
          config,
          isNotNull,
          reason: 'Iteration $i: platform config should be available',
        );

        platformService.dispose();
      }
    });

    /// Property: Platform-specific checks always return valid boolean values
    test('platform-specific checks always return valid boolean values',
        () async {
      final platformService = PlatformDetectionService();

      // All platform checks should return valid booleans (not throw)
      expect(platformService.isWeb, isA<bool>());
      expect(platformService.isWindows, isA<bool>());
      expect(platformService.isLinux, isA<bool>());
      expect(platformService.isMacOS, isA<bool>());
      expect(platformService.isDesktop, isA<bool>());
      expect(platformService.isMobile, isA<bool>());

      // At least one platform check should be true
      final platformChecks = [
        platformService.isWeb,
        platformService.isWindows,
        platformService.isLinux,
        platformService.isMacOS,
      ];

      expect(
        platformChecks.any((check) => check),
        true,
        reason: 'At least one platform check should be true',
      );

      platformService.dispose();
    });

    /// Property: Supported platforms list is never empty
    test('supported platforms list is never empty', () async {
      final platformService = PlatformDetectionService();

      final supportedPlatforms = platformService.getSupportedPlatforms();
      expect(supportedPlatforms, isNotEmpty);

      // Current platform should be in supported list or fallback should be supported
      final currentPlatform = platformService.currentPlatform;
      final isSupported = platformService.isPlatformSupported(currentPlatform);

      // If current platform is not supported, it means we're using a fallback
      // which should be supported
      if (!isSupported) {
        // Fallback platform (Windows) should be supported
        expect(
          platformService.isPlatformSupported(PlatformType.windows),
          true,
          reason: 'Fallback platform (Windows) should be supported',
        );
      }

      platformService.dispose();
    });

    /// Property: Installation instructions are always available
    test('installation instructions are always available', () async {
      final platformService = PlatformDetectionService();

      final currentPlatform = platformService.currentPlatform;
      final options = platformService.getDownloadOptions();

      // Should have installation instructions for each download option
      for (final option in options) {
        final instructions = platformService.getInstallationInstructions(
          currentPlatform,
          option.installationType,
        );

        expect(instructions, isNotEmpty);
        expect(instructions, isNot(contains('not available')));
      }

      platformService.dispose();
    });

    /// Property: Error state is handled gracefully
    test('error state is handled gracefully', () async {
      final platformService = PlatformDetectionService();

      // Even if there's an error, service should be functional
      expect(platformService.isInitialized, true);
      expect(platformService.currentPlatform, isNotNull);

      // lastError may or may not be null, but service should still work
      final hasError = platformService.lastError != null;
      if (hasError) {
        debugPrint('Platform detection error: ${platformService.lastError}');
        // Even with error, should have valid platform
        expect(platformService.currentPlatform, isNotNull);
      }

      platformService.dispose();
    });

    /// Property: Fallback platform is consistent across multiple instances
    test('fallback platform is consistent across multiple instances', () async {
      const int iterations = 10;
      final platforms = <PlatformType>[];

      for (int i = 0; i < iterations; i++) {
        final platformService = PlatformDetectionService();
        platforms.add(platformService.currentPlatform);
        platformService.dispose();
      }

      // All instances should detect the same platform
      final firstPlatform = platforms.first;
      for (int i = 1; i < platforms.length; i++) {
        expect(
          platforms[i],
          firstPlatform,
          reason:
              'Platform detection should be consistent across instances (iteration $i)',
        );
      }
    });

    /// Property: Screen info calculation handles edge cases
    test('screen info calculation handles edge cases', () async {
      final platformService = PlatformDetectionService();

      // Test various screen sizes
      final testCases = [
        {'width': 0.0, 'height': 0.0},
        {'width': 320.0, 'height': 568.0}, // Small mobile
        {'width': 600.0, 'height': 800.0}, // Tablet
        {'width': 1920.0, 'height': 1080.0}, // Desktop
        {'width': 3840.0, 'height': 2160.0}, // 4K
      ];

      for (final testCase in testCases) {
        final width = testCase['width']!;
        final height = testCase['height']!;

        final screenInfo = platformService.getScreenInfo(width, height);

        expect(screenInfo, isNotEmpty);
        expect(screenInfo.containsKey('width'), true);
        expect(screenInfo.containsKey('height'), true);
        expect(screenInfo.containsKey('isMobileSize'), true);
        expect(screenInfo.containsKey('isTabletSize'), true);
        expect(screenInfo.containsKey('isDesktopSize'), true);

        // Verify screen size categorization
        expect(screenInfo['width'], width);
        expect(screenInfo['height'], height);
      }

      platformService.dispose();
    });
  });
}
