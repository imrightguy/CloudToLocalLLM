import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for managing GitHub releases and downloads
class GitHubReleaseService {
  static const String _repoOwner = 'CloudToLocalLLM-online';
  static const String _repoName = 'CloudToLocalLLM';
  static const String _baseApiUrl = 'https://api.github.com/repos';

  /// Get the latest release information
  Future<GitHubRelease?> getLatestRelease() async {
    try {
      final url = '$_baseApiUrl/$_repoOwner/$_repoName/releases/latest';
      final dio = Dio();
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        return GitHubRelease.fromJson(data);
      } else {
        debugPrint('Failed to fetch latest release: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching latest release: $e');
      return null;
    }
  }

  /// Get all releases
  Future<List<GitHubRelease>> getAllReleases() async {
    try {
      final url = '$_baseApiUrl/$_repoOwner/$_repoName/releases';
      final dio = Dio();
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => GitHubRelease.fromJson(json)).toList();
      } else {
        debugPrint('Failed to fetch releases: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching releases: $e');
      return [];
    }
  }

  /// Download a file using URL launcher
  Future<void> downloadFile(String downloadUrl, String fileName) async {
    try {
      final uri = Uri.parse(downloadUrl);

      if (await canLaunchUrl(uri)) {
        // Use external application mode to trigger download
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('Download initiated for: $fileName');
      } else {
        debugPrint('Could not launch download URL: $downloadUrl');
        throw Exception('Unable to launch download URL');
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      rethrow;
    }
  }

  /// Get download options for the latest release
  Future<List<DownloadOption>> getDownloadOptions() async {
    final release = await getLatestRelease();
    if (release == null) return [];

    return release.assets.map((asset) {
      return DownloadOption(
        name: asset.name,
        downloadUrl: asset.browserDownloadUrl,
        size: asset.size,
        contentType: asset.contentType,
        description: _getAssetDescription(asset.name),
      );
    }).toList();
  }

  String _getAssetDescription(String assetName) {
    if (assetName.contains('Setup.exe')) {
      return 'Windows Installer (Recommended) - Easy installation with desktop shortcuts';
    } else if (assetName.contains('portable.zip')) {
      return 'Portable ZIP - No installation required, extract and run';
    } else if (assetName.contains('.sha256')) {
      return 'SHA256 Checksum - For verifying file integrity';
    }
    return 'Download file';
  }
}

/// Model for GitHub release data
class GitHubRelease {
  final String tagName;
  final String name;
  final String body;
  final bool prerelease;
  final DateTime publishedAt;
  final List<GitHubAsset> assets;

  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.prerelease,
    required this.publishedAt,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      prerelease: json['prerelease'] ?? false,
      publishedAt: DateTime.parse(json['published_at']),
      assets: (json['assets'] as List<dynamic>?)
              ?.map((asset) => GitHubAsset.fromJson(asset))
              .toList() ??
          [],
    );
  }
}

/// Model for GitHub release asset
class GitHubAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;
  final String contentType;
  final int downloadCount;

  GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
    required this.contentType,
    required this.downloadCount,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] ?? '',
      browserDownloadUrl: json['browser_download_url'] ?? '',
      size: json['size'] ?? 0,
      contentType: json['content_type'] ?? '',
      downloadCount: json['download_count'] ?? 0,
    );
  }
}

/// Model for download options
class DownloadOption {
  final String name;
  final String downloadUrl;
  final int size;
  final String contentType;
  final String description;

  DownloadOption({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.contentType,
    required this.description,
  });

  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
