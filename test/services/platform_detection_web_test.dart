import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/models/platform_config.dart';

void main() {
  group('PlatformDetectionService Web Tests', () {
    late PlatformDetectionService service;

    setUp(() {
      service = PlatformDetectionService();
    });

    tearDown(() {
      service.dispose();
    });

    test('should provide user agent access method', () {
      // This test verifies the getUserAgent method exists and handles non-web gracefully
      final userAgent = service.getUserAgent();

      if (kIsWeb) {
        expect(userAgent, isNotNull);
        expect(userAgent, isA<String>());
      } else {
        expect(userAgent, isNull);
      }
    });

    test('should provide detection info for debugging', () {
      final info = service.getDetectionInfo();

      expect(info, isA<Map<String, dynamic>>());
      expect(info.containsKey('isWeb'), true);
      expect(info.containsKey('detectedPlatform'), true);
      expect(info.containsKey('selectedPlatform'), true);
      expect(info.containsKey('currentPlatform'), true);
      expect(info.containsKey('isInitialized'), true);
      expect(info.containsKey('userAgent'), true);

      expect(info['isWeb'], kIsWeb);
      expect(info['isInitialized'], true);

      if (kIsWeb) {
        expect(info['userAgent'], isA<String>());
      } else {
        expect(info['userAgent'], 'N/A (non-web)');
      }
    });

    test('should handle platform detection correctly based on environment', () {
      if (kIsWeb) {
        // In web environment, should attempt to detect from user agent
        expect(service.isInitialized, true);
        expect(service.detectedPlatform, isNotNull);
      } else {
        // In non-web environment, should default to unknown
        expect(service.isInitialized, true);
        expect(service.detectedPlatform, PlatformType.unknown);
      }
    });
  });

  group('PlatformType.fromUserAgent', () {
    test('should detect Windows from various user agents', () {
      final windowsUserAgents = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:54.0) Gecko/20100101',
        'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2)',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:91.0) Gecko/20100101',
      ];

      for (final userAgent in windowsUserAgents) {
        expect(
          PlatformType.fromUserAgent(userAgent),
          PlatformType.windows,
          reason: 'Failed to detect Windows from: $userAgent',
        );
      }
    });

    test('should detect macOS from various user agents', () {
      final macUserAgents = [
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:91.0) Gecko/20100101',
        'Mozilla/5.0 (Macintosh; PPC Mac OS X 10_5_8) AppleWebKit/534.50.2',
      ];

      for (final userAgent in macUserAgents) {
        expect(
          PlatformType.fromUserAgent(userAgent),
          PlatformType.macos,
          reason: 'Failed to detect macOS from: $userAgent',
        );
      }
    });

    test('should detect Linux from various user agents', () {
      final linuxUserAgents = [
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
        'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:91.0) Gecko/20100101',
        'Mozilla/5.0 (X11; Linux i686; rv:91.0) Gecko/20100101',
      ];

      for (final userAgent in linuxUserAgents) {
        expect(
          PlatformType.fromUserAgent(userAgent),
          PlatformType.linux,
          reason: 'Failed to detect Linux from: $userAgent',
        );
      }
    });

    test('should return unknown for unrecognized user agents', () {
      final unknownUserAgents = [
        'Mozilla/5.0 (Unknown OS) AppleWebKit/537.36',
        'SomeCustomBrowser/1.0',
        '',
        'Mobile Browser',
      ];

      for (final userAgent in unknownUserAgents) {
        expect(
          PlatformType.fromUserAgent(userAgent),
          PlatformType.unknown,
          reason: 'Should return unknown for: $userAgent',
        );
      }
    });
  });
}
