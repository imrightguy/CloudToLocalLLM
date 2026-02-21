import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/models/platform_config.dart';
import '../test_config.dart';

void main() {
  group('PlatformDetectionService', () {
    late PlatformDetectionService platformDetectionService;

    setUp(() {
      TestConfig.initialize();
      platformDetectionService = PlatformDetectionService();
    });

    tearDown(() {
      platformDetectionService.dispose();
      TestConfig.cleanup();
    });

    group('Initialization', () {
      test('should initialize with correct default state', () {
        expect(platformDetectionService.isInitialized, true);
        expect(platformDetectionService.detectedPlatform, isNotNull);
        expect(platformDetectionService.selectedPlatform, null);
      });

      test(
        'should have platform configurations for all supported platforms',
        () {
          final supportedPlatforms =
              platformDetectionService.getSupportedPlatforms();

          expect(supportedPlatforms, contains(PlatformType.windows));
          expect(supportedPlatforms, contains(PlatformType.linux));
          expect(supportedPlatforms, contains(PlatformType.macos));
          expect(supportedPlatforms.length, 3);
        },
      );
    });

    group('Platform Detection', () {
      test('should detect platform from user agent', () {
        final detectedPlatform = platformDetectionService.detectPlatform();

        expect(detectedPlatform, isA<PlatformType>());
        expect(platformDetectionService.detectedPlatform, detectedPlatform);
      });

      test('should refresh detection when requested', () {
        platformDetectionService.refreshDetection();

        expect(platformDetectionService.detectedPlatform, isNotNull);
      });
    });

    group('Manual Platform Selection', () {
      test('should allow manual platform selection', () {
        platformDetectionService.selectPlatform(PlatformType.linux);

        expect(platformDetectionService.selectedPlatform, PlatformType.linux);
        expect(platformDetectionService.currentPlatform, PlatformType.linux);
      });

      test('should clear manual platform selection', () {
        platformDetectionService.selectPlatform(PlatformType.windows);
        expect(platformDetectionService.selectedPlatform, PlatformType.windows);

        platformDetectionService.clearPlatformSelection();

        expect(platformDetectionService.selectedPlatform, null);
        expect(
          platformDetectionService.currentPlatform,
          platformDetectionService.detectedPlatform,
        );
      });
    });

    group('Download Options', () {
      test('should return download options for Windows', () {
        final options = platformDetectionService.getDownloadOptions(
          PlatformType.windows,
        );

        expect(options, isNotEmpty);
        expect(options.any((option) => option.installationType == 'msi'), true);
        expect(options.any((option) => option.installationType == 'zip'), true);
        expect(options.any((option) => option.isRecommended), true);
      }, skip: 'Platform-specific test');

      test('should return download options for Linux', () {
        final options = platformDetectionService.getDownloadOptions(
          PlatformType.linux,
        );

        expect(options, isNotEmpty);
        expect(
          options.any((option) => option.installationType == 'appimage'),
          true,
        );
        expect(options.any((option) => option.installationType == 'deb'), true);
        expect(options.any((option) => option.isRecommended), true);
      });

      test('should return download options for macOS', () {
        final options = platformDetectionService.getDownloadOptions(
          PlatformType.macos,
        );

        expect(options, isNotEmpty);
        expect(options.any((option) => option.installationType == 'dmg'), true);
        expect(options.any((option) => option.isRecommended), true);
      });

      test('should return empty list for unknown platform', () {
        final options = platformDetectionService.getDownloadOptions(
          PlatformType.unknown,
        );

        expect(options, isEmpty);
      });

      test(
        'should return download options for current platform when no platform specified',
        () {
          platformDetectionService.selectPlatform(PlatformType.windows);

          final options = platformDetectionService.getDownloadOptions();

          expect(options, isNotEmpty);
          expect(
            options.any((option) => option.installationType == 'msi'),
            true,
          );
        },
        skip: 'Platform-specific test',
      );
    });

    group('Installation Instructions', () {
      test('should return installation instructions for Windows MSI', () {
        final instructions = platformDetectionService
            .getInstallationInstructions(PlatformType.windows, 'msi');

        expect(instructions, isNotEmpty);
        expect(instructions.toLowerCase(), contains('installer'));
        expect(instructions.toLowerCase(), contains('windows'));
      });

      test('should return installation instructions for Linux AppImage', () {
        final instructions = platformDetectionService
            .getInstallationInstructions(PlatformType.linux, 'appimage');

        expect(instructions, isNotEmpty);
        expect(instructions.toLowerCase(), contains('appimage'));
        expect(instructions.toLowerCase(), contains('chmod'));
      });

      test('should return installation instructions for macOS DMG', () {
        final instructions = platformDetectionService
            .getInstallationInstructions(PlatformType.macos, 'dmg');

        expect(instructions, isNotEmpty);
        expect(instructions.toLowerCase(), contains('dmg'));
        expect(instructions.toLowerCase(), contains('applications'));
      });

      test('should return fallback message for unknown platform', () {
        final instructions = platformDetectionService
            .getInstallationInstructions(PlatformType.unknown, 'unknown');

        expect(instructions, contains('not available'));
      });

      test('should return fallback message for unknown download type', () {
        final instructions = platformDetectionService
            .getInstallationInstructions(PlatformType.windows, 'unknown_type');

        expect(instructions, contains('No specific installation steps'));
      });
    });

    group('Platform Configuration', () {
      test('should return platform configuration for supported platforms', () {
        final windowsConfig = platformDetectionService.getPlatformConfig(
          PlatformType.windows,
        );

        expect(windowsConfig, isNotNull);
        expect(windowsConfig!.platform, PlatformType.windows);
        expect(windowsConfig.displayName, 'Windows');
        expect(windowsConfig.downloadOptions, isNotEmpty);
        expect(windowsConfig.installationSteps, isNotEmpty);
      });

      test('should return null for unknown platform', () {
        final unknownConfig = platformDetectionService.getPlatformConfig(
          PlatformType.unknown,
        );

        expect(unknownConfig, null);
      });

      test(
        'should return current platform config when no platform specified',
        () {
          platformDetectionService.selectPlatform(PlatformType.linux);

          final config = platformDetectionService.getPlatformConfig();

          expect(config, isNotNull);
          expect(config!.platform, PlatformType.linux);
        },
      );
    });

    group('Platform Support', () {
      test('should correctly identify supported platforms', () {
        expect(
          platformDetectionService.isPlatformSupported(PlatformType.windows),
          true,
        );
        expect(
          platformDetectionService.isPlatformSupported(PlatformType.linux),
          true,
        );
        expect(
          platformDetectionService.isPlatformSupported(PlatformType.macos),
          true,
        );
        expect(
          platformDetectionService.isPlatformSupported(PlatformType.unknown),
          false,
        );
      });

      test('should return all supported platforms', () {
        final supportedPlatforms =
            platformDetectionService.getSupportedPlatforms();

        expect(supportedPlatforms.length, 3);
        expect(supportedPlatforms, contains(PlatformType.windows));
        expect(supportedPlatforms, contains(PlatformType.linux));
        expect(supportedPlatforms, contains(PlatformType.macos));
      });
    });

    group('Notification Behavior', () {
      test('should notify listeners when platform is manually selected', () {
        var notificationCount = 0;
        platformDetectionService.addListener(() {
          notificationCount++;
        });

        platformDetectionService.selectPlatform(PlatformType.windows);

        expect(notificationCount, 1);
      });

      test('should notify listeners when platform selection is cleared', () {
        var notificationCount = 0;

        // First select a platform
        platformDetectionService.selectPlatform(PlatformType.windows);

        // Then add listener and clear selection
        platformDetectionService.addListener(() {
          notificationCount++;
        });

        platformDetectionService.clearPlatformSelection();

        expect(notificationCount, 1);
      });

      test('should notify listeners when detection is refreshed', () {
        var notificationCount = 0;

        // Clear cache first to ensure refresh actually re-detects
        platformDetectionService.clearCache();

        platformDetectionService.addListener(() {
          notificationCount++;
        });

        platformDetectionService.refreshDetection();

        expect(notificationCount, 1);
      });
    });

    group('Edge Cases', () {
      test('should handle multiple rapid platform selections', () {
        platformDetectionService.selectPlatform(PlatformType.windows);
        platformDetectionService.selectPlatform(PlatformType.linux);
        platformDetectionService.selectPlatform(PlatformType.macos);

        expect(platformDetectionService.selectedPlatform, PlatformType.macos);
        expect(platformDetectionService.currentPlatform, PlatformType.macos);
      });

      test('should handle clearing selection when none is set', () {
        expect(platformDetectionService.selectedPlatform, null);

        expect(
          () => platformDetectionService.clearPlatformSelection(),
          returnsNormally,
        );

        expect(platformDetectionService.selectedPlatform, null);
      });
    });

    group('Platform Information', () {
      test('should provide platform information getters', () {
        expect(platformDetectionService.isWeb, isA<bool>());
        expect(platformDetectionService.isWindows, isA<bool>());
        expect(platformDetectionService.isLinux, isA<bool>());
        expect(platformDetectionService.isMacOS, isA<bool>());
        expect(platformDetectionService.isDesktop, isA<bool>());
        expect(platformDetectionService.isMobile, isA<bool>());
      });

      test('should provide detection info with caching', () {
        final info1 = platformDetectionService.getDetectionInfo();
        expect(info1, isA<Map<String, dynamic>>());
        expect(info1['isWeb'], isA<bool>());
        expect(info1['isWindows'], isA<bool>());
        expect(info1['isLinux'], isA<bool>());
        expect(info1['isMacOS'], isA<bool>());
        expect(info1['isDesktop'], isA<bool>());
        expect(info1['isMobile'], isA<bool>());
        expect(info1['cachedAt'], isA<String>());

        // Second call should return cached value
        final info2 = platformDetectionService.getDetectionInfo();
        expect(info2['cachedAt'], equals(info1['cachedAt']));
      });

      test('should provide screen info', () {
        final screenInfo = platformDetectionService.getScreenInfo(800, 600);
        expect(screenInfo['width'], equals(800));
        expect(screenInfo['height'], equals(600));
        expect(screenInfo['isMobileSize'], isA<bool>());
        expect(screenInfo['isTabletSize'], isA<bool>());
        expect(screenInfo['isDesktopSize'], isA<bool>());
      });

      test('should correctly categorize screen sizes', () {
        final mobileInfo = platformDetectionService.getScreenInfo(400, 800);
        expect(mobileInfo['isMobileSize'], true);
        expect(mobileInfo['isTabletSize'], false);
        expect(mobileInfo['isDesktopSize'], false);

        final tabletInfo = platformDetectionService.getScreenInfo(768, 1024);
        expect(tabletInfo['isMobileSize'], false);
        expect(tabletInfo['isTabletSize'], true);
        expect(tabletInfo['isDesktopSize'], false);

        final desktopInfo = platformDetectionService.getScreenInfo(1920, 1080);
        expect(desktopInfo['isMobileSize'], false);
        expect(desktopInfo['isTabletSize'], false);
        expect(desktopInfo['isDesktopSize'], true);
      });
    });

    group('Caching', () {
      test('should cache platform detection', () {
        final platform1 = platformDetectionService.detectPlatform();
        final platform2 = platformDetectionService.detectPlatform();

        expect(platform1, equals(platform2));
      });

      test('should clear cache when requested', () {
        platformDetectionService.getDetectionInfo();

        expect(
          () => platformDetectionService.clearCache(),
          returnsNormally,
        );
      });
    });
  });

  group('PlatformType', () {
    group('User Agent Detection', () {
      test('should detect Windows from user agent', () {
        expect(
          PlatformType.fromUserAgent(
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          ),
          PlatformType.windows,
        );
        expect(
          PlatformType.fromUserAgent(
            'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2)',
          ),
          PlatformType.windows,
        );
      });

      test('should detect macOS from user agent', () {
        expect(
          PlatformType.fromUserAgent(
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
          ),
          PlatformType.macos,
        );
        expect(
          PlatformType.fromUserAgent(
            'Mozilla/5.0 (Macintosh; PPC Mac OS X 10_5_8)',
          ),
          PlatformType.macos,
        );
      });

      test('should detect Linux from user agent', () {
        expect(
          PlatformType.fromUserAgent('Mozilla/5.0 (X11; Linux x86_64)'),
          PlatformType.linux,
        );
        expect(
          PlatformType.fromUserAgent('Mozilla/5.0 (X11; Ubuntu; Linux x86_64)'),
          PlatformType.linux,
        );
      });

      test('should return unknown for unrecognized user agent', () {
        expect(
          PlatformType.fromUserAgent('Unknown Browser/1.0'),
          PlatformType.unknown,
        );
        expect(PlatformType.fromUserAgent(''), PlatformType.unknown);
      });
    });

    group('Flutter Platform Detection', () {
      test('should detect platforms from Flutter platform strings', () {
        expect(
          PlatformType.fromFlutterPlatform('windows'),
          PlatformType.windows,
        );
        expect(PlatformType.fromFlutterPlatform('linux'), PlatformType.linux);
        expect(PlatformType.fromFlutterPlatform('macos'), PlatformType.macos);
        expect(
          PlatformType.fromFlutterPlatform('unknown'),
          PlatformType.unknown,
        );
      });

      test('should handle case insensitive platform strings', () {
        expect(
          PlatformType.fromFlutterPlatform('WINDOWS'),
          PlatformType.windows,
        );
        expect(PlatformType.fromFlutterPlatform('Linux'), PlatformType.linux);
        expect(PlatformType.fromFlutterPlatform('MacOS'), PlatformType.macos);
      });
    });

    group('Installation Type Support', () {
      test('should correctly identify Windows installation types', () {
        expect(PlatformType.windows.supportsInstallationType('msi'), true);
        expect(PlatformType.windows.supportsInstallationType('zip'), true);
        expect(PlatformType.windows.supportsInstallationType('exe'), true);
        expect(PlatformType.windows.supportsInstallationType('deb'), false);
      });

      test('should correctly identify Linux installation types', () {
        expect(PlatformType.linux.supportsInstallationType('deb'), true);
        expect(PlatformType.linux.supportsInstallationType('appimage'), true);
        expect(PlatformType.linux.supportsInstallationType('tar.gz'), true);
        expect(PlatformType.linux.supportsInstallationType('snap'), true);
        expect(PlatformType.linux.supportsInstallationType('aur'), true);
        expect(PlatformType.linux.supportsInstallationType('msi'), false);
      });

      test('should correctly identify macOS installation types', () {
        expect(PlatformType.macos.supportsInstallationType('dmg'), true);
        expect(PlatformType.macos.supportsInstallationType('pkg'), true);
        expect(PlatformType.macos.supportsInstallationType('zip'), true);
        expect(PlatformType.macos.supportsInstallationType('deb'), false);
      });

      test('should return false for unknown platform', () {
        expect(PlatformType.unknown.supportsInstallationType('msi'), false);
        expect(PlatformType.unknown.supportsInstallationType('deb'), false);
        expect(PlatformType.unknown.supportsInstallationType('dmg'), false);
      });

      test('should handle case insensitive installation types', () {
        expect(PlatformType.windows.supportsInstallationType('MSI'), true);
        expect(PlatformType.linux.supportsInstallationType('DEB'), true);
        expect(PlatformType.macos.supportsInstallationType('DMG'), true);
      });
    });

    group('Display Names', () {
      test('should have correct display names', () {
        expect(PlatformType.windows.displayName, 'Windows');
        expect(PlatformType.linux.displayName, 'Linux');
        expect(PlatformType.macos.displayName, 'macOS');
        expect(PlatformType.unknown.displayName, 'Unknown');
      });
    });
  });
}
