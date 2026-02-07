// Web stub for NativeTrayService - not available on web
import 'package:flutter/foundation.dart';
import 'connection_manager_service.dart';

/// Stub mixin for TrayListener - not needed on web
mixin TrayListener {}

/// Web stub for NativeTrayService
class NativeTrayService with TrayListener {
  static final NativeTrayService _instance = NativeTrayService._internal();
  factory NativeTrayService() => _instance;
  NativeTrayService._internal();

  bool _isInitialized = false;
  bool _isSupported = false;

  bool get isInitialized => _isInitialized;
  bool get isSupported => _isSupported;

  Future<bool> initialize({
    ConnectionManagerService? connectionManager,
    void Function()? onShowWindow,
    void Function()? onHideWindow,
    void Function()? onSettings,
    void Function()? onQuit,
  }) async {
    debugPrint('[NativeTray] System tray not supported on web platform');
    _isSupported = false;
    _isInitialized = false;
    return false;
  }

  void updateConnectionManager(ConnectionManagerService connectionManager) {
    // Stub - no-op on web
  }

  void dispose() {}
}
