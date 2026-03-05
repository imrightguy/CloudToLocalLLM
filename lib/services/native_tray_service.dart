import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'connection_manager_service.dart';
import '../utils/logger.dart';

/// Tray connection status enumeration
enum TrayConnectionStatus {
  allConnected,
  partiallyConnected,
  connecting,
  disconnected,
}

/// Native Flutter system tray service for CloudToLocalLLM
///
/// Note: Ollama integration removed. Uses ConnectionManagerService only.
class NativeTrayService with TrayListener {
  static final NativeTrayService _instance = NativeTrayService._internal();
  factory NativeTrayService() => _instance;
  NativeTrayService._internal();

  bool _isInitialized = false;
  bool _isSupported = false;
  ConnectionManagerService? _connectionManager;
  StreamSubscription? _statusSubscription;
  Timer? _updateDebounceTimer;
  TrayConnectionStatus? _lastStatus;

  // Callbacks for tray events
  void Function()? _onShowWindow;
  void Function()? _onHideWindow;
  void Function()? _onSettings;
  void Function()? _onQuit;

  /// Check if system tray is supported on this platform
  bool get isSupported => _isSupported;

  /// Check if tray service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the native tray service
  Future<bool> initialize({
    ConnectionManagerService? connectionManager,
    void Function()? onShowWindow,
    void Function()? onHideWindow,
    void Function()? onSettings,
    void Function()? onQuit,
  }) async {
    if (_isInitialized) return true;

    try {
      appLogger.debug('[NativeTray] Initializing native tray service...');

      // Check platform support - web platforms don't support native tray
      if (kIsWeb) {
        _isSupported = false;
        appLogger.warning(
          '[NativeTray] System tray not supported on web platform',
        );
        return false;
      }

      try {
        _isSupported =
            Platform.isLinux || Platform.isWindows || Platform.isMacOS;
        if (!_isSupported) {
          appLogger.warning(
            '[NativeTray] System tray not supported on this platform',
          );
          return false;
        }
      } catch (e) {
        appLogger.error('[NativeTray] Platform detection failed', error: e);
        _isSupported = false;
        return false;
      }

      // Store connection manager and callbacks
      if (connectionManager != null) {
        _connectionManager = connectionManager;
      }
      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onSettings = onSettings;
      _onQuit = onQuit;

      // Initialize tray manager
      await trayManager
          .setIcon(_getTrayIconPath(TrayConnectionStatus.disconnected));

      // Listen to connection changes
      if (_connectionManager != null) {
        _connectionManager!.addListener(_onConnectionStatusChanged);
      }

      // Set up initial menu
      await _updateTrayMenu();

      // Add tray listener
      trayManager.addListener(this);

      _isInitialized = true;
      appLogger
          .info('[NativeTray] Native tray service initialized successfully');
      return true;
    } catch (e) {
      appLogger.error('[NativeTray] Failed to initialize tray service',
          error: e);
      return false;
    }
  }

  /// Get the current connection status
  TrayConnectionStatus _getCurrentStatus() {
    if (_connectionManager == null) {
      return TrayConnectionStatus.disconnected;
    }

    final hasCloud = _connectionManager!.hasCloudConnection;

    if (hasCloud) {
      return TrayConnectionStatus.allConnected;
    }
    return TrayConnectionStatus.disconnected;
  }

  /// Get tray icon path based on connection status
  String _getTrayIconPath(TrayConnectionStatus status) {
    switch (status) {
      case TrayConnectionStatus.allConnected:
        return 'assets/images/tray_icon_connected.png';
      case TrayConnectionStatus.partiallyConnected:
      case TrayConnectionStatus.connecting:
        return 'assets/images/tray_icon_connecting.png';
      case TrayConnectionStatus.disconnected:
        return 'assets/images/tray_icon_disconnected.png';
    }
  }

  /// Update tray menu based on current status
  Future<void> _updateTrayMenu() async {
    final status = _getCurrentStatus();
    _lastStatus = status;

    try {
      await trayManager.setIcon(_getTrayIconPath(status));

      final Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show',
            label: 'Show CloudToLocalLLM',
          ),
          MenuItem(
            key: 'hide',
            label: 'Hide to Tray',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'status',
            label: 'Status: ${_getStatusLabel(status)}',
            disabled: true,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'settings',
            label: 'Settings',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: 'Quit',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);

      // setToolTip not implemented on Linux, wrap in try-catch
      try {
        await trayManager
            .setToolTip('CloudToLocalLLM - ${_getStatusLabel(status)}');
      } catch (e) {
        // setToolTip not supported on this platform, ignore
        appLogger.debug('[NativeTray] setToolTip not supported: $e');
      }
    } catch (e) {
      appLogger.error('[NativeTray] Failed to update tray menu', error: e);
    }
  }

  /// Get human-readable status label
  String _getStatusLabel(TrayConnectionStatus status) {
    switch (status) {
      case TrayConnectionStatus.allConnected:
        return 'Connected';
      case TrayConnectionStatus.partiallyConnected:
        return 'Partially Connected';
      case TrayConnectionStatus.connecting:
        return 'Connecting...';
      case TrayConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  /// Handle connection status changes
  void _onConnectionStatusChanged() {
    // Debounce updates to prevent rapid menu rebuilds
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      final currentStatus = _getCurrentStatus();
      if (currentStatus != _lastStatus) {
        _updateTrayMenu();
      }
    });
  }

  /// TrayListener: Handle tray icon click
  @override
  void onTrayIconMouseDown() {
    _onShowWindow?.call();
  }

  /// TrayListener: Handle tray icon right-click
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  /// TrayListener: Handle menu item click
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _onShowWindow?.call();
        break;
      case 'hide':
        _onHideWindow?.call();
        break;
      case 'settings':
        _onSettings?.call();
        break;
      case 'quit':
        _onQuit?.call();
        break;
    }
  }

  /// Dispose tray service
  Future<void> dispose() async {
    _updateDebounceTimer?.cancel();
    await _statusSubscription?.cancel();
    _connectionManager?.removeListener(_onConnectionStatusChanged);
    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }
}
