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

/// Native Flutter system tray service
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

  bool get isSupported => _isSupported;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize({
    ConnectionManagerService? connectionManager,
    void Function()? onShowWindow,
    void Function()? onHideWindow,
    void Function()? onSettings,
    void Function()? onQuit,
  }) async {
    if (_isInitialized) return true;

    try {
      _isSupported = (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
      if (!_isSupported) return false;

      _connectionManager = connectionManager;
      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onSettings = onSettings;
      _onQuit = onQuit;

      trayManager.addListener(this);

      await _setupTray();
      _isInitialized = true;

      if (_connectionManager != null) {
        _connectionManager!.addListener(_onConnectionChanged);
      }

      return true;
    } catch (e) {
      appLogger.error('[NativeTray] Failed to initialize tray', error: e);
      return false;
    }
  }

  void updateConnectionManager(ConnectionManagerService connectionManager) {
    if (_connectionManager != null) {
      _connectionManager!.removeListener(_onConnectionChanged);
    }
    _connectionManager = connectionManager;
    _connectionManager!.addListener(_onConnectionChanged);
    _onConnectionChanged();
  }

  Future<void> _setupTray() async {
    try {
      String iconPath = Platform.isWindows
          ? 'assets/images/app_icon.ico'
          : 'assets/images/app_icon.png';

      await trayManager.setIcon(iconPath);
      await _updateTrayMenu();
      await trayManager.setToolTip('CloudToLocalLLM');
    } catch (e) {
      appLogger.error('[NativeTray] Error setting up tray', error: e);
    }
  }

  Future<void> _updateTrayMenu() async {
    if (!_isSupported) return;

    final status = _getConnectionStatus();
    String statusLabel = 'Status: Disconnected';
    if (status == TrayConnectionStatus.allConnected) {
      statusLabel = 'Status: Connected';
    } else if (status == TrayConnectionStatus.connecting) {
      statusLabel = 'Status: Connecting...';
    }

    List<MenuItem> items = [
      MenuItem(
        key: 'show_window',
        label: 'Show Dashboard',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'status',
        label: statusLabel,
        disabled: true,
      ),
      MenuItem(
        key: 'settings',
        label: 'Settings',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'quit',
        label: 'Quit',
      ),
    ];

    await trayManager.setContextMenu(Menu(items: items));
  }

  TrayConnectionStatus _getConnectionStatus() {
    if (_connectionManager == null) return TrayConnectionStatus.disconnected;
    if (_connectionManager!.isConnected) return TrayConnectionStatus.allConnected;
    return TrayConnectionStatus.disconnected;
  }

  void _onConnectionChanged() {
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      final currentStatus = _getConnectionStatus();
      if (currentStatus != _lastStatus) {
        _lastStatus = currentStatus;
        _updateTrayMenu();
      }
    });
  }

  @override
  void onTrayIconMouseDown() {
    _onShowWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        _onShowWindow?.call();
        break;
      case 'settings':
        _onSettings?.call();
        break;
      case 'quit':
        _onQuit?.call();
        break;
    }
  }

  void dispose() {
    _updateDebounceTimer?.cancel();
    _statusSubscription?.cancel();
    _connectionManager?.removeListener(_onConnectionChanged);
    trayManager.removeListener(this);
  }
}
