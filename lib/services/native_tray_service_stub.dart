/// Native tray service stub - for platforms without native tray support
library;

import 'connection_manager_service.dart';

/// Stub for NativeTrayService on unsupported platforms
class NativeTrayService {
  bool get isSupported => false;
  bool get isInitialized => false;

  Future<bool> initialize({
    ConnectionManagerService? connectionManager,
    void Function()? onShowWindow,
    void Function()? onHideWindow,
    void Function()? onSettings,
    void Function()? onQuit,
  }) async {
    return false;
  }

  Future<void> dispose() async {}
}
