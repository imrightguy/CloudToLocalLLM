import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// Service for managing download links, tracking, and validation
class DownloadManagementService extends ChangeNotifier {
  static const String _githubApiUrl =
      'https://api.github.com/repos/CloudToLocalLLM-online/CloudToLocalLLM';
  static const String _githubReleasesUrl = '$_githubApiUrl/releases';

  // Cache for GitHub release data
  Map<String, dynamic>? _latestReleaseCache;
  DateTime? _cacheTimestamp;
  static const Duration _cacheExpiry = Duration(minutes: 15);

  // Download tracking
  final Map<String, DownloadTrackingInfo> _downloadTracking = {};

  /// Generate secure download URL for a specific platform and package type
  Future<String> generateDownloadUrl(
    String platform,
    String packageType,
  ) async {
    try {
      final latestRelease = await _getLatestRelease();
      final assets = latestRelease['assets'] as List<dynamic>;

      // Find the appropriate asset based on platform and package type
      final assetName = _getAssetName(platform, packageType);
      final asset = assets.firstWhere(
        (asset) => (asset['name'] as String).contains(assetName),
        orElse: () => null,
      );

      if (asset != null) {
        final downloadUrl = asset['browser_download_url'] as String;
        debugPrint(
          '� [DownloadManagement] Generated download URL for $platform/$packageType: $downloadUrl',
        );
        return downloadUrl;
      } else {
        // Fallback to constructed URL if asset not found in release
        final fallbackUrl = _constructFallbackUrl(platform, packageType);
        debugPrint(
          '� [DownloadManagement] Using fallback URL for $platform/$packageType: $fallbackUrl',
        );
        return fallbackUrl;
      }
    } catch (e) {
      debugPrint('� [DownloadManagement] Error generating download URL: $e');
      // Return fallback URL on error
      return _constructFallbackUrl(platform, packageType);
    }
  }

  /// Get latest release information from GitHub API
  Future<Map<String, dynamic>> _getLatestRelease() async {
    // Check cache first
    if (_latestReleaseCache != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheExpiry) {
      return _latestReleaseCache!;
    }

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      final response = await dio.get(
        '$_githubReleasesUrl/latest',
        options: Options(headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CloudToLocalLLM/${AppConfig.appVersion}',
        }),
      );

      if (response.statusCode == 200) {
        _latestReleaseCache = response.data as Map<String, dynamic>;
        _cacheTimestamp = DateTime.now();
        debugPrint(
          '� [DownloadManagement] Fetched latest release: ${_latestReleaseCache!['tag_name']}',
        );
        return _latestReleaseCache!;
      } else {
        throw Exception('GitHub API returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('� [DownloadManagement] Error fetching latest release: $e');
      // Return cached data if available, otherwise throw
      if (_latestReleaseCache != null) {
        return _latestReleaseCache!;
      }
      rethrow;
    }
  }

  /// Get asset name pattern for platform and package type
  String _getAssetName(String platform, String packageType) {
    switch (platform.toLowerCase()) {
      case 'windows':
        switch (packageType.toLowerCase()) {
          case 'exe':
          case 'msi':
            return 'CloudToLocalLLM-Windows-';
          case 'zip':
            return 'CloudToLocalLLM-';
          default:
            return 'Windows';
        }
      case 'linux':
        switch (packageType.toLowerCase()) {
          case 'appimage':
            return 'x86_64.AppImage';
          case 'deb':
            return '_amd64.deb';
          case 'tar.gz':
            return 'linux-x64.tar.gz';
          default:
            return 'linux';
        }
      case 'macos':
        switch (packageType.toLowerCase()) {
          case 'dmg':
            return 'macos.dmg';
          default:
            return 'macos';
        }
      default:
        return platform;
    }
  }

  /// Construct fallback download URL when GitHub API is unavailable
  String _constructFallbackUrl(String platform, String packageType) {
    final baseUrl = '${AppConfig.githubUrl}/releases/latest/download';
    final version = AppConfig.appVersion;

    switch (platform.toLowerCase()) {
      case 'windows':
        switch (packageType.toLowerCase()) {
          case 'exe':
          case 'msi':
            return '$baseUrl/CloudToLocalLLM-Windows-$version-Setup.exe';
          case 'zip':
            return '$baseUrl/cloudtolocalllm-$version-portable.zip';
          default:
            return '$baseUrl/CloudToLocalLLM-Windows-$version-Setup.exe';
        }
      case 'linux':
        switch (packageType.toLowerCase()) {
          case 'appimage':
            return '$baseUrl/cloudtolocalllm-$version-x86_64.AppImage';
          case 'deb':
            return '$baseUrl/cloudtolocalllm_${version}_amd64.deb';
          case 'tar.gz':
            return '$baseUrl/cloudtolocalllm-$version-x86_64.tar.gz';
          default:
            return '$baseUrl/cloudtolocalllm-$version-x86_64.AppImage';
        }
      case 'macos':
        switch (packageType.toLowerCase()) {
          case 'dmg':
            return '$baseUrl/cloudtolocalllm-$version-macos.dmg';
          default:
            return '$baseUrl/cloudtolocalllm-$version-macos.dmg';
        }
      default:
        return AppConfig.githubReleasesUrl;
    }
  }

  /// Validate downloaded file (basic validation)
  Future<bool> validateDownload(String filePath) async {
    try {
      // For web platform, we can't directly validate files
      // This would be implemented for desktop platforms
      if (kIsWeb) {
        debugPrint(
          '� [DownloadManagement] File validation not available on web platform',
        );
        return true; // Assume valid for web
      }

      // Implement basic file validation for desktop platforms
      try {
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('� [DownloadManagement] File does not exist: $filePath');
          return false;
        }

        final fileSize = await file.length();
        if (fileSize == 0) {
          debugPrint('� [DownloadManagement] File is empty: $filePath');
          return false;
        }

        // Basic file format validation based on extension
        final extension = filePath.split('.').last.toLowerCase();
        final validExtensions = [
          'exe',
          'msi',
          'dmg',
          'pkg',
          'deb',
          'rpm',
          'tar.gz',
          'zip',
        ];

        if (!validExtensions.contains(extension)) {
          debugPrint(
            '� [DownloadManagement] Invalid file extension: $extension',
          );
          return false;
        }

        debugPrint(
          '� [DownloadManagement] File validation passed for: $filePath',
        );
        return true;
      } catch (e) {
        debugPrint('� [DownloadManagement] File validation error: $e');
        return false;
      }
    } catch (e) {
      debugPrint('� [DownloadManagement] Error validating download: $e');
      return false;
    }
  }

  /// Get alternative download URLs (mirrors)
  Future<List<String>> getAlternativeDownloadUrls(String platform) async {
    final alternatives = <String>[];

    try {
      // Add GitHub releases page as primary alternative
      alternatives.add(AppConfig.githubReleasesUrl);

      // Add direct GitHub download links for common packages
      final version = AppConfig.appVersion;
      final baseUrl = '${AppConfig.githubUrl}/releases/latest/download';

      switch (platform.toLowerCase()) {
        case 'windows':
          alternatives.add(
            '$baseUrl/CloudToLocalLLM-Windows-$version-Setup.exe',
          );
          alternatives.add('$baseUrl/cloudtolocalllm-$version-portable.zip');
          break;
        case 'linux':
          alternatives.add('$baseUrl/cloudtolocalllm-$version-x86_64.AppImage');
          alternatives.add('$baseUrl/cloudtolocalllm_${version}_amd64.deb');
          alternatives.add('$baseUrl/cloudtolocalllm-$version-x86_64.tar.gz');
          break;
        case 'macos':
          alternatives.add('$baseUrl/cloudtolocalllm-$version-macos.dmg');
          break;
      }

      debugPrint(
        '� [DownloadManagement] Generated ${alternatives.length} alternative URLs for $platform',
      );
    } catch (e) {
      debugPrint(
        '� [DownloadManagement] Error generating alternative URLs: $e',
      );
    }

    return alternatives;
  }

  /// Track download event for analytics
  Future<void> trackDownloadEvent(
    String userId,
    String platform,
    String packageType,
  ) async {
    final trackingInfo = DownloadTrackingInfo(
      userId: userId,
      platform: platform,
      packageType: packageType,
      timestamp: DateTime.now(),
      userAgent: kIsWeb ? _getUserAgent() : 'Desktop',
    );

    final trackingKey = '${userId}_${platform}_$packageType';
    _downloadTracking[trackingKey] = trackingInfo;

    debugPrint(
      '� [DownloadManagement] Tracked download: $platform/$packageType for user $userId',
    );

    // Send analytics to backend if analytics are enabled
    if (AppConfig.enableAnalytics) {
      await _sendAnalytics(trackingInfo);
    }

    notifyListeners();
  }

  /// Get user agent string (web only)
  String _getUserAgent() {
    if (kIsWeb) {
      try {
        // This would need to be implemented with dart:html
        return 'Web Browser';
      } catch (e) {
        return 'Unknown';
      }
    }
    return 'Desktop';
  }

  /// Send analytics data to backend
  Future<void> _sendAnalytics(DownloadTrackingInfo trackingInfo) async {
    try {
      // Implement analytics endpoint call
      final analyticsData = {
        'event': 'download_tracked',
        'platform': trackingInfo.platform,
        'package_type': trackingInfo.packageType,
        'user_id': trackingInfo.userId,
        'timestamp': trackingInfo.timestamp.toIso8601String(),
        'user_agent': trackingInfo.userAgent,
      };

      // For now, just log the analytics data
      // In production, this would send to an analytics service via Dio
      debugPrint(
        '� [DownloadManagement] Analytics data: ${jsonEncode(analyticsData)}',
      );
    } catch (e) {
      debugPrint('� [DownloadManagement] Error sending analytics: $e');
    }
  }

  /// Get download statistics
  Map<String, dynamic> getDownloadStatistics() {
    final stats = <String, dynamic>{};

    // Count downloads by platform
    final platformCounts = <String, int>{};
    final packageTypeCounts = <String, int>{};

    for (final tracking in _downloadTracking.values) {
      platformCounts[tracking.platform] =
          (platformCounts[tracking.platform] ?? 0) + 1;
      packageTypeCounts[tracking.packageType] =
          (packageTypeCounts[tracking.packageType] ?? 0) + 1;
    }

    stats['totalDownloads'] = _downloadTracking.length;
    stats['platformCounts'] = platformCounts;
    stats['packageTypeCounts'] = packageTypeCounts;
    stats['lastDownload'] = _downloadTracking.values.isNotEmpty
        ? _downloadTracking.values
            .map((t) => t.timestamp)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    return stats;
  }

  /// Clear download tracking data
  void clearTrackingData() {
    _downloadTracking.clear();
    debugPrint('� [DownloadManagement] Cleared download tracking data');
    notifyListeners();
  }

  /// Get cached release information
  Map<String, dynamic>? get cachedReleaseInfo => _latestReleaseCache;

  /// Check if cache is valid
  bool get isCacheValid =>
      _latestReleaseCache != null &&
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheExpiry;

  /// Force refresh cache
  Future<void> refreshCache() async {
    _latestReleaseCache = null;
    _cacheTimestamp = null;
    await _getLatestRelease();
    notifyListeners();
  }

  @override
  void dispose() {
    _downloadTracking.clear();
    super.dispose();
  }
}

/// Information about a download event for tracking
class DownloadTrackingInfo {
  final String userId;
  final String platform;
  final String packageType;
  final DateTime timestamp;
  final String userAgent;

  const DownloadTrackingInfo({
    required this.userId,
    required this.platform,
    required this.packageType,
    required this.timestamp,
    required this.userAgent,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'platform': platform,
      'packageType': packageType,
      'timestamp': timestamp.toIso8601String(),
      'userAgent': userAgent,
    };
  }

  @override
  String toString() {
    return 'DownloadTrackingInfo(platform: $platform, packageType: $packageType, timestamp: $timestamp)';
  }
}
