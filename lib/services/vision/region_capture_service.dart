import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Result of a region capture operation
class CaptureResult {
  final String path;
  final int width;
  final int height;
  final DateTime timestamp;

  const CaptureResult({
    required this.path,
    required this.width,
    required this.height,
    required this.timestamp,
  });

  @override
  String toString() =>
      'CaptureResult(path: $path, width: $width, height: $height, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CaptureResult &&
        other.path == path &&
        other.width == width &&
        other.height == height &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode =>
      path.hashCode ^ width.hashCode ^ height.hashCode ^ timestamp.hashCode;
}

/// Service for capturing specific regions of the screen
class RegionCaptureService {
  static const MethodChannel _channel =
      MethodChannel('cloudtolocallm/region_capture');

  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  String? get lastError => _lastError;

  /// Initialize the region capture service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[RegionCapture] Already initialized');
      return;
    }

    // Web platform doesn't support screen capture
    if (kIsWeb) {
      _lastError = 'Region capture not supported on web platform';
      debugPrint('[RegionCapture] $_lastError');
      return;
    }

    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
      _lastError = null;
      debugPrint('[RegionCapture] Initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize: $e';
      debugPrint('[RegionCapture] $_lastError');
    }
  }

  /// Capture a specific region of the screen
  Future<CaptureResult?> captureRegion({
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    if (!_isInitialized) {
      throw StateError('RegionCaptureService not initialized');
    }

    // Validate parameters
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Width and height must be positive');
    }

    if (x < 0 || y < 0) {
      throw ArgumentError('Coordinates must be non-negative');
    }

    if (_isCapturing) {
      debugPrint('[RegionCapture] Already capturing, ignoring request');
      return null;
    }

    _isCapturing = true;
    _lastError = null;

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/capture_$timestamp.png';

      debugPrint(
          '[RegionCapture] Capturing region: x=$x, y=$y, w=$width, h=$height');

      final result = await _channel.invokeMethod('captureRegion', {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'path': path,
      });

      if (result == true && File(path).existsSync()) {
        debugPrint('[RegionCapture] Capture saved to $path');
        return CaptureResult(
          path: path,
          width: width,
          height: height,
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
        );
      } else {
        _lastError = 'Capture failed or file not created';
        debugPrint('[RegionCapture] $_lastError');
        return null;
      }
    } catch (e) {
      _lastError = 'Capture failed: $e';
      debugPrint('[RegionCapture] $_lastError');
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  /// Get the screen size
  Future<ScreenSize?> getScreenSize() async {
    if (!_isInitialized) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod('getScreenSize');
      if (result is Map) {
        return ScreenSize(
          width: result['width'] as int,
          height: result['height'] as int,
        );
      }
      return null;
    } catch (e) {
      _lastError = 'Failed to get screen size: $e';
      debugPrint('[RegionCapture] $_lastError');
      return null;
    }
  }
}

/// Screen size data class
class ScreenSize {
  final int width;
  final int height;

  const ScreenSize({
    required this.width,
    required this.height,
  });

  @override
  String toString() => 'ScreenSize(width: $width, height: $height)';
}
