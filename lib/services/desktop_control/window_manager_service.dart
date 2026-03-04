import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Window information class
class WindowInfo {
  final String id;
  final String title;
  final String appName;
  final int x;
  final int y;
  final int width;
  final int height;
  final bool isMinimized;
  final bool isMaximized;
  final bool isActive;

  WindowInfo({
    required this.id,
    required this.title,
    required this.appName,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isMinimized = false,
    this.isMaximized = false,
    this.isActive = false,
  });

  factory WindowInfo.fromMap(Map<String, dynamic> map) {
    return WindowInfo(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      x: map['x'] as int? ?? 0,
      y: map['y'] as int? ?? 0,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      isMinimized: map['isMinimized'] as bool? ?? false,
      isMaximized: map['isMaximized'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'appName': appName,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'isMinimized': isMinimized,
      'isMaximized': isMaximized,
      'isActive': isActive,
    };
  }

  @override
  String toString() {
    return 'WindowInfo(id: $id, title: $title, appName: $appName, x: $x, y: $y, width: $width, height: $height)';
  }
}

/// Window Manager Service
/// Provides window management functionality: focus, move, resize, minimize, maximize, close
class WindowManagerService {
  static const MethodChannel _channel =
      MethodChannel('cloudtolocallm/window_manager');

  bool _isInitialized = false;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  /// Initialize the window manager service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[WindowManager] Already initialized, skipping');
      return;
    }

    debugPrint('[WindowManager] Initializing...');
    _isInitialized = true;
    _lastError = null;
    debugPrint('[WindowManager] Initialized successfully');
  }

  /// Get list of all windows
  Future<List<WindowInfo>> getWindows() async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[WindowManager] $error');
      throw StateError(error);
    }

    debugPrint('[WindowManager] Getting windows...');
    try {
      final result = await _channel.invokeMethod('getWindows');
      if (result is List) {
        final windows = result
            .map((item) => WindowInfo.fromMap(item as Map<String, dynamic>))
            .toList();
        debugPrint('[WindowManager] Found ${windows.length} windows');
        _lastError = null;
        return windows;
      }
      debugPrint('[WindowManager] No windows found or invalid response');
      return [];
    } catch (e) {
      _lastError = 'Failed to get windows: $e';
      debugPrint('[WindowManager] $_lastError');
      return [];
    }
  }

  /// Focus a window by ID
  Future<bool> focusWindow(String windowId) async {
    debugPrint('[WindowManager] Focusing window: $windowId');
    try {
      final result = await _channel.invokeMethod('focusWindow', {
        'windowId': windowId,
      });
      _lastError = null;
      debugPrint('[WindowManager] Focus window result: $result');
      return result == true;
    } catch (e) {
      _lastError = 'Failed to focus window: $e';
      debugPrint('[WindowManager] $_lastError');
      return false;
    }
  }

  /// Move a window to new coordinates
  Future<bool> moveWindow(String windowId, int x, int y) async {
    debugPrint('[WindowManager] Moving window $windowId to ($x, $y)');
    try {
      final result = await _channel.invokeMethod('moveWindow', {
        'windowId': windowId,
        'x': x,
        'y': y,
      });
      _lastError = null;
      debugPrint('[WindowManager] Move window result: $result');
      return result == true;
    } catch (e) {
      _lastError = 'Failed to move window: $e';
      debugPrint('[WindowManager] $_lastError');
      return false;
    }
  }

  /// Resize a window
  Future<bool> resizeWindow(String windowId, int width, int height) async {
    debugPrint('[WindowManager] Resizing window $windowId to ${width}x$height');
    try {
      final result = await _channel.invokeMethod('resizeWindow', {
        'windowId': windowId,
        'width': width,
        'height': height,
      });
      _lastError = null;
      debugPrint('[WindowManager] Resize window result: $result');
      return result == true;
    } catch (e) {
      _lastError = 'Failed to resize window: $e';
      debugPrint('[WindowManager] $_lastError');
      return false;
    }
  }

  /// Minimize a window
  Future<bool> minimizeWindow(String windowId) async {
    debugPrint('[WindowManager] Minimizing window: $windowId');
    try {
      final result = await _channel.invokeMethod('minimizeWindow', {
        'windowId': windowId,
      });
      _lastError = null;
      debugPrint('[WindowManager] Minimize window result: $result');
      return result == true;
    } catch (e) {
      _lastError = 'Failed to minimize window: $e';
      debugPrint('[WindowManager] $_lastError');
      return false;
    }
  }

  /// Maximize a window
  Future<bool> maximizeWindow(String windowId) async {
    debugPrint('[WindowManager] Maximizing window: $windowId');
    try {
      final result = await _channel.invokeMethod('maximizeWindow', {
        'windowId': windowId,
      });
      _lastError = null;
      debugPrint('[WindowManager] Maximize window result: $result');
      return result == true;
    } catch (e) {
      _lastError = 'Failed to maximize window: $e';
      debugPrint('[WindowManager] $_lastError');
      return false;
    }
  }

  /// Toggle maximize state (for double-click title bar behavior)
  Future<bool> toggleMaximize(String windowId) async {
    debugPrint('[WindowManager] Toggling maximize for window: $windowId');
    try {
      final result = await _channel.invokeMethod('toggleMaximize', {
        'windowId': windowId,
      });
      _lastError = null;
      debugPrint('[WindowManager] Toggle maximize result: $result');
      return result == true;
    } catch (e) {
      _lastError = 'Failed to toggle maximize: $e';
      debugPrint('[WindowManager] $_lastError');
      return false;
    }
  }

  /// Close a window
  Future<bool> closeWindow(String windowId) async {
    debugPrint('[WindowManager] Closing window: $windowId');
    try {
      final result = await _channel.invokeMethod('closeWindow', {
        'windowId': windowId,
      });
      _lastError = null;
      debugPrint('[WindowManager] Close window result: $result');
      return result == true;
    } catch (e) {
      _lastError = 'Failed to close window: $e';
      debugPrint('[WindowManager] $_lastError');
      return false;
    }
  }

  /// Dispose of the window manager service
  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    debugPrint('[WindowManager] Disposing...');
    _isInitialized = false;
    _lastError = null;
    debugPrint('[WindowManager] Disposed successfully');
  }
}
