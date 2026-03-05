import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Semantic version components
class VersionComponents {
  final int major;
  final int minor;
  final int patch;

  const VersionComponents({
    required this.major,
    required this.minor,
    required this.patch,
  });

  @override
  String toString() => '$major.$minor.$patch';
}

/// Update type classification
enum UpdateType {
  major,
  minor,
  patch,
  none,
}

/// Update status
enum UpdateStatus {
  checking,
  upToDate,
  updateAvailable,
  downloading,
  downloaded,
  installing,
  installed,
  error,
}

/// Update information
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final UpdateType type;
  final String? changelog;
  final DateTime? releaseDate;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.type,
    this.changelog,
    this.releaseDate,
  });
}

/// Auto-update service for CloudToLocalLLM
class AutoUpdateService extends ChangeNotifier {
  // Singleton pattern
  static final AutoUpdateService _instance = AutoUpdateService._internal();
  factory AutoUpdateService() => _instance;
  AutoUpdateService._internal();

  // State
  UpdateStatus _status = UpdateStatus.upToDate;
  UpdateInfo? _updateInfo;
  String? _errorMessage;
  Timer? _checkTimer;

  // Getters
  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  String? get errorMessage => _errorMessage;

  // Socket path for daemon communication
  static const String _socketPath = '/tmp/cloudtolocalllm-updated.sock';

  /// Parse semantic version string
  VersionComponents parseVersion(String version) {
    final parts = version.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid version format: $version');
    }

    return VersionComponents(
      major: int.parse(parts[0]),
      minor: int.parse(parts[1]),
      patch: int.parse(parts[2]),
    );
  }

  /// Compare two versions
  UpdateType compareVersions(String current, String latest) {
    final currentVer = parseVersion(current);
    final latestVer = parseVersion(latest);

    if (latestVer.major > currentVer.major) {
      return UpdateType.major;
    } else if (latestVer.minor > currentVer.minor) {
      return UpdateType.minor;
    } else if (latestVer.patch > currentVer.patch) {
      return UpdateType.patch;
    }

    return UpdateType.none;
  }

  /// Check for updates
  Future<void> checkForUpdates() async {
    _status = UpdateStatus.checking;
    notifyListeners();

    try {
      // Try to communicate with daemon via socket
      final update = await _checkWithDaemon();

      if (update != null) {
        _updateInfo = update;
        _status = UpdateStatus.updateAvailable;
        notifyListeners();
        return;
      }

      // Fallback to direct GitHub API check
      await _checkWithGitHubAPI();
    } catch (e) {
      _errorMessage = e.toString();
      _status = UpdateStatus.error;
      notifyListeners();
    }
  }

  /// Check with local daemon
  Future<UpdateInfo?> _checkWithDaemon() async {
    final socketFile = File(_socketPath);
    if (!socketFile.existsSync()) {
      return null;
    }

    try {
      // Attempt to connect to Unix socket
      // Note: Unix socket support will be implemented in follow-up
      await Socket.connect('localhost', 0);

      // For now, return null - will implement Unix socket in follow-up
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check with GitHub API directly
  Future<void> _checkWithGitHubAPI() async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(Uri.parse(
          'https://api.github.com/repos/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest'));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch release info: ${response.statusCode}');
      }

      final content = await response.transform(utf8.decoder).join();
      final data = json.decode(content);

      final tagName = data['tag_name'] as String;
      final latestVersion = tagName.replaceFirst('v', '');
      final currentVersion = _getCurrentVersion();

      final updateType = compareVersions(currentVersion, latestVersion);

      if (updateType != UpdateType.none) {
        _updateInfo = UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          type: updateType,
          changelog: data['body'] as String?,
          releaseDate: DateTime.tryParse(data['published_at'] as String? ?? ''),
        );
        _status = UpdateStatus.updateAvailable;
      } else {
        _status = UpdateStatus.upToDate;
      }

      notifyListeners();
    } finally {
      client.close();
    }
  }

  /// Get current version from package info
  String _getCurrentVersion() {
    // This will be implemented using package_info_plus
    // For now, return a placeholder
    return '10.1.200';
  }

  /// Download update
  Future<void> downloadUpdate() async {
    if (_updateInfo == null) {
      throw Exception('No update available to download');
    }

    _status = UpdateStatus.downloading;
    notifyListeners();

    // Download logic will be implemented
    // For now, mark as downloaded
    await Future.delayed(const Duration(seconds: 2));

    _status = UpdateStatus.downloaded;
    notifyListeners();
  }

  /// Install update
  Future<void> installUpdate() async {
    if (_updateInfo == null) {
      throw Exception('No update available to install');
    }

    _status = UpdateStatus.installing;
    notifyListeners();

    // Install logic will be implemented
    // For now, mark as installed
    await Future.delayed(const Duration(seconds: 1));

    _status = UpdateStatus.installed;
    notifyListeners();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
