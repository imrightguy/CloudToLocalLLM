/// CloudToLocalLLM Shared Version Management
///
/// Provides version constants and compatibility checks across all applications
library;

import 'package:package_info_plus/package_info_plus.dart';

/// Version constants for all CloudToLocalLLM components
class CloudToLocalLLMVersions {
  // Main application version
  static const String mainAppVersion = '4.3.0';
  static const int mainAppBuildNumber = 202511062338;

  // Tunnel manager version (integrated in v3.5.0+)
  static const String tunnelManagerVersion = '4.3.0';
  static const int tunnelManagerBuildNumber = 202511062338;

  // Shared library version
  static const String sharedLibraryVersion = '4.3.0';
  static const int sharedLibraryBuildNumber = 202511062338;

  // Tray daemon version (deprecated - now integrated)
  static const String trayDaemonVersion = 'deprecated';

  // Build timestamp (updated during build process)
  static const String buildTimestamp = '2025-11-07T04:38:03Z';

  // Git commit hash (updated during build process)
  static const String gitCommitHash = 'production-v3.10.1';
}

/// Version compatibility checker
class VersionCompatibility {
  /// Check if shared library version is compatible with app version
  static bool isSharedLibraryCompatible(String appVersion) {
    final appMajor = _getMajorVersion(appVersion);
    final sharedMajor = _getMajorVersion(
      CloudToLocalLLMVersions.sharedLibraryVersion,
    );

    // Major versions must match for compatibility
    return appMajor == sharedMajor;
  }

  /// Check if tray daemon version is compatible with app version
  static bool isTrayDaemonCompatible(String appVersion) {
    final appMajor = _getMajorVersion(appVersion);
    final trayMajor = _getMajorVersion(
      CloudToLocalLLMVersions.trayDaemonVersion,
    );

    // For now, require exact major version match
    // In future, could implement more sophisticated compatibility matrix
    return appMajor >= 3 && trayMajor >= 2;
  }

  /// Extract major version number from version string
  static int _getMajorVersion(String version) {
    final parts = version.split('.');
    if (parts.isEmpty) return 0;
    return int.tryParse(parts[0]) ?? 0;
  }

  /// Get version compatibility report
  static Future<Map<String, dynamic>> getCompatibilityReport() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    return {
      'current_app_version': currentVersion,
      'current_build_number': packageInfo.buildNumber,
      'shared_library_compatible': isSharedLibraryCompatible(currentVersion),
      'tray_daemon_compatible': isTrayDaemonCompatible(currentVersion),
      'versions': {
        'main_app': CloudToLocalLLMVersions.mainAppVersion,
        'tunnel_manager': CloudToLocalLLMVersions.tunnelManagerVersion,
        'shared_library': CloudToLocalLLMVersions.sharedLibraryVersion,
        'tray_daemon': CloudToLocalLLMVersions.trayDaemonVersion,
      },
      'build_info': {
        'timestamp': CloudToLocalLLMVersions.buildTimestamp,
        'git_commit': CloudToLocalLLMVersions.gitCommitHash,
      },
    };
  }
}

/// Version display utilities
class VersionDisplay {
  /// Format version for UI display
  static String formatVersion(String version, int buildNumber) {
    return '$version+$buildNumber';
  }

  /// Get short version string (major.minor)
  static String getShortVersion(String version) {
    final parts = version.split('.');
    if (parts.length >= 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return version;
  }

  /// Get version with build timestamp for tooltips
  static String getDetailedVersion(String version, int buildNumber) {
    return '$version+$buildNumber (${CloudToLocalLLMVersions.buildTimestamp})';
  }
}
