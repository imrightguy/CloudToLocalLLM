import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/platform_config.dart';
import '../models/download_option.dart';
import '../models/installation_step.dart';
import '../config/app_config.dart';

// Conditional imports for web platform detection
import '../utils/web_interop_stub.dart'
    if (dart.library.html) '../utils/web_interop.dart';

/// Service for detecting user's platform and providing appropriate download options
class PlatformDetectionService extends ChangeNotifier {
  PlatformType? _detectedPlatform;
  PlatformType? _selectedPlatform;
  bool _isInitialized = false;
  String? _lastError;

  // Platform detection caching
  DateTime? _lastDetectionTime;
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  // Platform configurations
  late final Map<PlatformType, PlatformConfig> _platformConfigs;

  // Platform information cache
  Map<String, dynamic>? _cachedPlatformInfo;

  // Default fallback platform for error recovery (Requirement 17.2)
  static const PlatformType _defaultFallbackPlatform = PlatformType.windows;

  PlatformDetectionService() {
    _initializePlatformConfigs();
    // Always detect platform during initialization
    detectPlatform();
  }

  // Getters
  PlatformType? get detectedPlatform => _detectedPlatform;
  PlatformType? get selectedPlatform => _selectedPlatform;
  PlatformType get currentPlatform =>
      _selectedPlatform ?? _detectedPlatform ?? _defaultFallbackPlatform;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  /// Initialize platform configurations with download options and installation steps
  void _initializePlatformConfigs() {
    _platformConfigs = {
      PlatformType.windows: _createWindowsConfig(),
      PlatformType.linux: _createLinuxConfig(),
      PlatformType.macos: _createMacOSConfig(),
    };
    _isInitialized = true;
  }

  /// Detect platform from browser user agent or native platform
  /// Implements error recovery as per Requirement 17.2
  PlatformType detectPlatform() {
    // Check if cached detection is still valid
    if (_detectedPlatform != null &&
        _lastDetectionTime != null &&
        DateTime.now().difference(_lastDetectionTime!) <
            _cacheValidityDuration) {
      debugPrint(
          ' [PlatformDetection] Using cached platform: $_detectedPlatform');
      return _detectedPlatform!;
    }

    _lastError = null;

    if (!kIsWeb) {
      // For non-web platforms, detect from dart:io Platform
      try {
        if (Platform.isWindows) {
          _detectedPlatform = PlatformType.windows;
        } else if (Platform.isLinux) {
          _detectedPlatform = PlatformType.linux;
        } else if (Platform.isMacOS) {
          _detectedPlatform = PlatformType.macos;
        } else if (Platform.isAndroid) {
          _detectedPlatform = PlatformType.unknown; // Android not in enum yet
        } else if (Platform.isIOS) {
          _detectedPlatform = PlatformType.unknown; // iOS not in enum yet
        } else {
          _detectedPlatform = PlatformType.unknown;
        }

        debugPrint(
          ' [PlatformDetection] Native platform detected: $_detectedPlatform',
        );
      } catch (e) {
        _lastError = 'Failed to detect native platform: $e';
        debugPrint(' [PlatformDetection] Error detecting native platform: $e');

        // Error recovery: use default fallback platform (Requirement 17.2)
        _detectedPlatform = _defaultFallbackPlatform;
        debugPrint(
          ' [PlatformDetection] Using fallback platform: $_detectedPlatform',
        );
      }

      _isInitialized = true;
      _lastDetectionTime = DateTime.now();
      notifyListeners();
      return _detectedPlatform!;
    }

    try {
      // Web platform - detect from browser user agent
      final userAgent = window.navigator.userAgent;

      debugPrint(
        ' [PlatformDetection] Web platform detected, user agent: $userAgent',
      );

      _detectedPlatform = PlatformType.fromUserAgent(userAgent);

      debugPrint(' [PlatformDetection] Detected platform: $_detectedPlatform');

      _isInitialized = true;
      _lastDetectionTime = DateTime.now();
      notifyListeners();
      return _detectedPlatform!;
    } catch (e) {
      _lastError = 'Failed to detect web platform: $e';
      debugPrint(' [PlatformDetection] Error detecting platform: $e');

      // Error recovery: use default fallback platform (Requirement 17.2)
      _detectedPlatform = _defaultFallbackPlatform;
      debugPrint(
        ' [PlatformDetection] Using fallback platform: $_detectedPlatform',
      );

      _isInitialized = true;
      _lastDetectionTime = DateTime.now();
      notifyListeners();
      return _detectedPlatform!;
    }
  }

  /// Manually set the selected platform (override detection)
  void selectPlatform(PlatformType platform) {
    _selectedPlatform = platform;
    debugPrint(' [PlatformDetection] Manually selected platform: $platform');
    notifyListeners();
  }

  /// Clear manual platform selection (revert to detection)
  void clearPlatformSelection() {
    _selectedPlatform = null;
    debugPrint(
      ' [PlatformDetection] Cleared manual platform selection, reverting to detected: $_detectedPlatform',
    );
    notifyListeners();
  }

  /// Get download options for the current platform
  List<DownloadOption> getDownloadOptions([PlatformType? platform]) {
    final targetPlatform = platform ?? currentPlatform;
    final config = _platformConfigs[targetPlatform];
    return config?.downloadOptions ?? [];
  }

  /// Get installation instructions for a specific platform and download type
  String getInstallationInstructions(
    PlatformType platform,
    String downloadType,
  ) {
    final config = _platformConfigs[platform];
    if (config == null) {
      return 'Installation instructions not available for this platform.';
    }

    final steps = config.getInstallationSteps(downloadType);
    if (steps.isEmpty) {
      return 'No specific installation steps found for $downloadType on ${platform.displayName}.';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Installation Instructions for ${platform.displayName} ($downloadType):',
    );
    buffer.writeln();

    for (final step in steps..sort((a, b) => a.order.compareTo(b.order))) {
      buffer.writeln('${step.order + 1}. ${step.title}');
      buffer.writeln('   ${step.description}');

      if (step.commands.isNotEmpty) {
        buffer.writeln('   Commands:');
        for (final command in step.commands) {
          buffer.writeln('   \$ $command');
        }
      }

      if (step.troubleshootingTips.isNotEmpty) {
        buffer.writeln('   Troubleshooting:');
        for (final tip in step.troubleshootingTips) {
          buffer.writeln('   • $tip');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Get platform configuration
  PlatformConfig? getPlatformConfig([PlatformType? platform]) {
    final targetPlatform = platform ?? currentPlatform;
    return _platformConfigs[targetPlatform];
  }

  /// Get all supported platforms
  List<PlatformType> getSupportedPlatforms() {
    return _platformConfigs.keys.toList();
  }

  /// Check if a platform is supported
  bool isPlatformSupported(PlatformType platform) {
    return _platformConfigs.containsKey(platform);
  }

  /// Create Windows platform configuration
  PlatformConfig _createWindowsConfig() {
    return PlatformConfig(
      platform: PlatformType.windows,
      displayName: 'Windows',
      iconPath: 'assets/images/windows-icon.png',
      downloadOptions: [
        DownloadOption(
          name: 'Windows Installer (Setup.exe)',
          description:
              'Recommended for most users. Includes automatic updates and system integration.',
          downloadUrl:
              'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-Windows-${AppConfig.appVersion}-Setup.exe',
          fileSize: '~10 MB',
          installationType: 'exe',
          isRecommended: true,
          requirements: [
            'Windows 10 or later',
            'Administrator privileges for installation',
          ],
        ),
        DownloadOption(
          name: 'Portable ZIP',
          description: 'No installation required. Extract and run directly.',
          downloadUrl:
              'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-portable.zip',
          fileSize: '~12 MB',
          installationType: 'zip',
          requirements: ['Windows 10 or later'],
        ),
      ],
      installationSteps: [
        InstallationStep(
          title: 'Download the installer',
          description:
              'Click the download link above to get the MSI installer.',
          applicableTypes: ['msi'],
          order: 0,
        ),
        InstallationStep(
          title: 'Run the installer',
          description:
              'Double-click the downloaded MSI file and follow the installation wizard.',
          applicableTypes: ['msi'],
          order: 1,
          troubleshootingTips: [
            'If Windows Defender blocks the installer, click "More info" then "Run anyway"',
            'You may need administrator privileges to install',
          ],
        ),
        InstallationStep(
          title: 'Launch the application',
          description:
              'Find CloudToLocalLLM in your Start menu or desktop shortcut.',
          applicableTypes: ['msi'],
          order: 2,
        ),
        InstallationStep(
          title: 'Extract the archive',
          description:
              'Right-click the ZIP file and select "Extract All" or use your preferred archive tool.',
          applicableTypes: ['zip'],
          order: 0,
        ),
        InstallationStep(
          title: 'Run the executable',
          description:
              'Navigate to the extracted folder and double-click CloudToLocalLLM.exe.',
          applicableTypes: ['zip'],
          order: 1,
          troubleshootingTips: [
            'If Windows Defender blocks the executable, add an exception',
            'You can create a desktop shortcut for easier access',
          ],
        ),
      ],
      troubleshootingGuides: {
        'windows_defender':
            'If Windows Defender blocks the application, go to Windows Security > Virus & threat protection > Manage settings > Add or remove exclusions.',
        'admin_rights':
            'If installation fails due to permissions, right-click the installer and select "Run as administrator".',
        'missing_dependencies':
            'Ensure you have the latest Visual C++ Redistributable installed from Microsoft.',
      },
      requiredDependencies: [
        'Windows 10 version 1903 or later',
        'Visual C++ Redistributable 2019 or later',
      ],
    );
  }

  /// Create Linux platform configuration
  PlatformConfig _createLinuxConfig() {
    return PlatformConfig(
      platform: PlatformType.linux,
      displayName: 'Linux',
      iconPath: 'assets/images/linux-icon.png',
      downloadOptions: [
        DownloadOption(
          name: 'AppImage (Universal)',
          description:
              'Portable application that runs on any Linux distribution. No installation required.',
          downloadUrl:
              'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-x86_64.AppImage',
          fileSize: '~48 MB',
          installationType: 'appimage',
          isRecommended: true,
          requirements: ['x86_64 architecture', 'FUSE or AppImage runtime'],
        ),
        DownloadOption(
          name: 'Debian Package (.deb)',
          description:
              'Native package for Ubuntu, Debian, and derivatives with proper dependency management.',
          downloadUrl:
              'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm_${AppConfig.appVersion}_amd64.deb',
          fileSize: '~44 MB',
          installationType: 'deb',
          requirements: [
            'Ubuntu 20.04+, Debian 11+, or compatible',
            'dpkg package manager',
          ],
        ),
        DownloadOption(
          name: 'Arch Linux (AUR)',
          description:
              'Pre-built binary package for Arch Linux and derivatives.',
          downloadUrl: 'https://aur.archlinux.org/packages/CloudToLocalLLM',
          fileSize: '~42 MB',
          installationType: 'aur',
          requirements: [
            'Arch Linux or derivative',
            'AUR helper (yay, paru, etc.)',
          ],
        ),
      ],
      installationSteps: [
        InstallationStep(
          title: 'Download AppImage',
          description: 'Click the download link to get the AppImage file.',
          applicableTypes: ['appimage'],
          order: 0,
        ),
        InstallationStep(
          title: 'Make executable',
          description: 'Open terminal and make the AppImage executable.',
          commands: [
            'chmod +x CloudToLocalLLM-${AppConfig.appVersion}-x86_64.AppImage',
          ],
          applicableTypes: ['appimage'],
          order: 1,
        ),
        InstallationStep(
          title: 'Run the application',
          description: 'Double-click the AppImage or run it from terminal.',
          commands: [
            './cloudtolocalllm-${AppConfig.appVersion}-x86_64.AppImage',
          ],
          applicableTypes: ['appimage'],
          order: 2,
          troubleshootingTips: [
            'If AppImage doesn\'t run, install FUSE: sudo apt install fuse',
            'For system tray support, install libayatana-appindicator',
          ],
        ),
        InstallationStep(
          title: 'Download DEB package',
          description: 'Download the .deb file for your system.',
          applicableTypes: ['deb'],
          order: 0,
        ),
        InstallationStep(
          title: 'Install package',
          description: 'Install using dpkg or your package manager.',
          commands: [
            'sudo dpkg -i cloudtolocalllm_${AppConfig.appVersion}_amd64.deb',
            'sudo apt-get install -f  # Fix dependencies if needed',
          ],
          applicableTypes: ['deb'],
          order: 1,
        ),
        InstallationStep(
          title: 'Install from AUR',
          description: 'Use your preferred AUR helper to install.',
          commands: [
            'yay -S CloudToLocalLLM',
            '# Or: paru -S CloudToLocalLLM',
            '# Or: pamac install CloudToLocalLLM',
          ],
          applicableTypes: ['aur'],
          order: 0,
        ),
      ],
      troubleshootingGuides: {
        'appimage_not_running':
            'Install FUSE support: sudo apt install fuse libfuse2',
        'system_tray_missing':
            'Install system tray support: sudo apt install libayatana-appindicator3-1',
        'deb_dependencies': 'Fix broken dependencies: sudo apt-get install -f',
        'permission_denied': 'Ensure the file is executable: chmod +x filename',
      },
      requiredDependencies: [
        'x86_64 (64-bit) architecture',
        'GLIBC 2.31 or later',
        'libayatana-appindicator3-1 (for system tray)',
        'FUSE (for AppImage)',
      ],
    );
  }

  /// Create macOS platform configuration
  PlatformConfig _createMacOSConfig() {
    return PlatformConfig(
      platform: PlatformType.macos,
      displayName: 'macOS',
      iconPath: 'assets/images/macos-icon.png',
      downloadOptions: [
        DownloadOption(
          name: 'macOS Application (.dmg)',
          description:
              'Standard macOS installer with drag-and-drop installation.',
          downloadUrl:
              'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-macos.dmg',
          fileSize: '~50 MB',
          installationType: 'dmg',
          isRecommended: true,
          requirements: [
            'macOS 11.0 (Big Sur) or later',
            'Intel or Apple Silicon Mac',
          ],
        ),
      ],
      installationSteps: [
        InstallationStep(
          title: 'Download DMG file',
          description: 'Click the download link to get the macOS installer.',
          applicableTypes: ['dmg'],
          order: 0,
        ),
        InstallationStep(
          title: 'Open the installer',
          description: 'Double-click the downloaded DMG file to mount it.',
          applicableTypes: ['dmg'],
          order: 1,
        ),
        InstallationStep(
          title: 'Install the application',
          description: 'Drag CloudToLocalLLM to your Applications folder.',
          applicableTypes: ['dmg'],
          order: 2,
        ),
        InstallationStep(
          title: 'Launch the application',
          description:
              'Find CloudToLocalLLM in your Applications folder and launch it.',
          applicableTypes: ['dmg'],
          order: 3,
          troubleshootingTips: [
            'If macOS blocks the app, go to System Preferences > Security & Privacy and click "Open Anyway"',
            'You may need to right-click the app and select "Open" the first time',
          ],
        ),
      ],
      troubleshootingGuides: {
        'gatekeeper_blocked':
            'If Gatekeeper blocks the app, go to System Preferences > Security & Privacy > General and click "Open Anyway".',
        'quarantine_attribute':
            'Remove quarantine attribute: xattr -d com.apple.quarantine /Applications/CloudToLocalLLM.app',
        'permission_denied':
            'Ensure you have permission to write to Applications folder.',
      },
      requiredDependencies: [
        'macOS 11.0 (Big Sur) or later',
        'Intel x64 or Apple Silicon (M1/M2) processor',
      ],
    );
  }

  /// Re-detect platform (useful for testing or manual refresh)
  void refreshDetection() {
    detectPlatform();
  }

  /// Get the current user agent string (web only)
  String? getUserAgent() {
    if (!kIsWeb) {
      return null;
    }

    try {
      return window.navigator.userAgent;
    } catch (e) {
      debugPrint(' [PlatformDetection] Error getting user agent: $e');
      return null;
    }
  }

  /// Get platform detection information for debugging
  Map<String, dynamic> getDetectionInfo() {
    if (_cachedPlatformInfo != null &&
        _lastDetectionTime != null &&
        DateTime.now().difference(_lastDetectionTime!) <
            _cacheValidityDuration) {
      return _cachedPlatformInfo!;
    }

    _cachedPlatformInfo = {
      'isWeb': kIsWeb,
      'isWindows': isWindows,
      'isLinux': isLinux,
      'isMacOS': isMacOS,
      'isDesktop': isDesktop,
      'isMobile': isMobile,
      'detectedPlatform': _detectedPlatform?.name,
      'selectedPlatform': _selectedPlatform?.name,
      'currentPlatform': currentPlatform.name,
      'isInitialized': _isInitialized,
      'userAgent': kIsWeb ? getUserAgent() : 'N/A (non-web)',
      'cachedAt': DateTime.now().toIso8601String(),
    };

    return _cachedPlatformInfo!;
  }

  /// Check if running on web platform
  bool get isWeb => kIsWeb;

  /// Check if running on Windows
  bool get isWindows {
    if (!kIsWeb) {
      try {
        return Platform.isWindows;
      } catch (e) {
        return false;
      }
    }
    return currentPlatform == PlatformType.windows;
  }

  /// Check if running on Linux
  bool get isLinux {
    if (!kIsWeb) {
      try {
        return Platform.isLinux;
      } catch (e) {
        return false;
      }
    }
    return currentPlatform == PlatformType.linux;
  }

  /// Check if running on macOS
  bool get isMacOS {
    if (!kIsWeb) {
      try {
        return Platform.isMacOS;
      } catch (e) {
        return false;
      }
    }
    return currentPlatform == PlatformType.macos;
  }

  /// Check if running on desktop platform (Windows, Linux, macOS)
  bool get isDesktop => isWindows || isLinux || isMacOS;

  /// Check if running on mobile platform (iOS, Android)
  bool get isMobile {
    if (!kIsWeb) {
      try {
        return Platform.isAndroid || Platform.isIOS;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Clear platform detection cache
  void clearCache() {
    _cachedPlatformInfo = null;
    _lastDetectionTime = null;
    debugPrint(' [PlatformDetection] Cache cleared');
  }

  /// Get screen size information (requires BuildContext in actual usage)
  /// This is a placeholder for component selection logic
  Map<String, dynamic> getScreenInfo(double width, double height) {
    return {
      'width': width,
      'height': height,
      'isMobileSize': width < 600,
      'isTabletSize': width >= 600 && width < 1024,
      'isDesktopSize': width >= 1024,
    };
  }
}
