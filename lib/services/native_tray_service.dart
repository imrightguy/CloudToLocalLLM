import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'connection_manager_service.dart';
import 'local_ollama_connection_service.dart';
import '../utils/logger.dart';

/// Tray connection status enumeration
enum TrayConnectionStatus {
  allConnected,
  partiallyConnected,
  connecting,
  disconnected,
}

/// Native Flutter system tray service for CloudToLocalLLM v3.3.1+
///
/// Replaces the Python-based tray daemon with a pure Flutter implementation
/// using the tray_manager package for cross-platform system tray functionality.
class NativeTrayService with TrayListener {
  static final NativeTrayService _instance = NativeTrayService._internal();
  factory NativeTrayService() => _instance;
  NativeTrayService._internal();

  bool _isInitialized = false;
  bool _isSupported = false;
  ConnectionManagerService? _connectionManager;
  LocalOllamaConnectionService? _localOllama;
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
    ConnectionManagerService? connectionManager, // Made nullable
    required LocalOllamaConnectionService localOllama,
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

      // Store references
      _connectionManager = connectionManager;
      _localOllama = localOllama;
      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onSettings = onSettings;
      _onQuit = onQuit;

      // Initialize tray manager with basic setup first
      try {
        final iconPath = _getIconPath(TrayConnectionStatus.disconnected);
        appLogger.debug('[NativeTray] Setting tray icon: $iconPath');
        await trayManager.setIcon(iconPath);
        appLogger.debug('[NativeTray] Tray icon set successfully');
      } catch (e) {
        appLogger.warning('[NativeTray] Failed to set tray icon: $e');
        // Try with a fallback icon using platform-specific format
        try {
          final fallbackExtension = Platform.isWindows ? '.ico' : '.png';
          await trayManager.setIcon(
            'assets/images/tray_icon$fallbackExtension',
          );
          appLogger.debug('[NativeTray] Fallback tray icon set successfully');
        } catch (fallbackError) {
          appLogger.error(
            '[NativeTray] Fallback tray icon also failed',
            error: fallbackError,
          );
        }
      }

      // Set up context menu first (this is more reliable)
      try {
        await _updateContextMenu();
        appLogger.debug('[NativeTray] Context menu set successfully');
      } catch (e) {
        appLogger.warning('[NativeTray] Failed to set context menu: $e');
        // Context menu setup failure is not critical for basic functionality
      }

      // Add listener for tray events
      trayManager.addListener(this);

      // Listen to connection manager status changes (if available)
      if (_connectionManager != null) {
        _connectionManager!.addListener(_onTunnelStatusChanged);
      }
      _localOllama!.addListener(_onTunnelStatusChanged);

      // Listen to streaming status events
      _setupStreamingStatusListener();

      // Try to set tooltip after other initialization (this might fail)
      try {
        await trayManager.setToolTip('CloudToLocalLLM - Initializing');
      } catch (e) {
        // Silently fail for MissingPluginException as it's common on some Linux distros
        if (e.toString().contains('MissingPluginException')) {
          appLogger
              .debug('[NativeTray] Tooltips not supported on this platform');
        } else {
          appLogger.warning('[NativeTray] Warning: Could not set tooltip: $e');
        }
      }

      _isInitialized = true;
      appLogger
          .info('[NativeTray] Native tray service initialized successfully');

      // Update initial status
      _onTunnelStatusChanged();

      return true;
    } catch (e) {
      appLogger.error(
        '[NativeTray] Failed to initialize native tray service',
        error: e,
      );
      // Don't fail the entire application if tray initialization fails
      return false;
    }
  }

  /// Setup streaming status event listener
  void _setupStreamingStatusListener() {
    // Streaming status events are now handled through service listeners
    // No separate event bus needed for simplified tunnel system
    _statusSubscription?.cancel();
  }

  /// Handle connection status changes from all services
  void _onTunnelStatusChanged() {
    if (!_isInitialized || _connectionManager == null) return;

    // Debounce updates to prevent constant refreshing
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      final status = _getOverallConnectionStatus();

      // Only update if status actually changed
      if (_lastStatus == status) {
        return;
      }

      _lastStatus = status;
      _updateTrayIcon(status);
      _updateTooltip(status);
      _updateContextMenu(); // Update menu with current status
    });
  }

  /// Get overall connection status from all services
  TrayConnectionStatus _getOverallConnectionStatus() {
    if (_localOllama == null) {
      return TrayConnectionStatus.disconnected;
    }

    final hasLocal = _localOllama!.isConnected;
    final hasCloud = _connectionManager?.hasCloudConnection ?? false;
    final isConnecting = _localOllama!.isConnecting;

    if (hasLocal && hasCloud) {
      return TrayConnectionStatus.allConnected;
    } else if (hasLocal || hasCloud) {
      return TrayConnectionStatus.partiallyConnected;
    } else if (isConnecting) {
      return TrayConnectionStatus.connecting;
    } else {
      return TrayConnectionStatus.disconnected;
    }
  }

  /// Update tray icon based on connection status
  Future<void> _updateTrayIcon(TrayConnectionStatus status) async {
    try {
      final iconPath = _getIconPath(status);
      await trayManager.setIcon(iconPath);
    } catch (e) {
      appLogger.warning('[NativeTray] Failed to update tray icon: $e');
    }
  }

  /// Update tooltip based on connection status
  Future<void> _updateTooltip(TrayConnectionStatus status) async {
    try {
      final tooltip = _getTooltipText(status);
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      // Silently fail for MissingPluginException
      if (!e.toString().contains('MissingPluginException')) {
        appLogger.warning('[NativeTray] Could not update tooltip: $e');
      }
    }
  }

  /// Get icon path for connection status with platform-specific format
  String _getIconPath(TrayConnectionStatus status) {
    // Use .ico files on Windows for better system tray compatibility
    // Use .png files on other platforms (Linux, macOS)
    final extension = Platform.isWindows ? '.ico' : '.png';

    switch (status) {
      case TrayConnectionStatus.allConnected:
        return 'assets/images/tray_icon_connected$extension';
      case TrayConnectionStatus.partiallyConnected:
        return 'assets/images/tray_icon_partial$extension';
      case TrayConnectionStatus.connecting:
        return 'assets/images/tray_icon_connecting$extension';
      case TrayConnectionStatus.disconnected:
        return 'assets/images/tray_icon_disconnected$extension';
    }
  }

  /// Get tooltip text for connection status
  String _getTooltipText(TrayConnectionStatus status) {
    if (_localOllama == null) {
      return 'CloudToLocalLLM - Initializing';
    }

    final hasLocal = _localOllama!.isConnected;
    final hasCloud = _connectionManager?.hasCloudConnection ?? false;
    final localEndpoint = 'http://localhost:11434';
    final cloudEndpoint = 'Tunnel';

    switch (status) {
      case TrayConnectionStatus.allConnected:
        return 'CloudToLocalLLM - All Connected\nLocal Ollama: $localEndpoint\nCloud Proxy: $cloudEndpoint';
      case TrayConnectionStatus.partiallyConnected:
        if (hasLocal && !hasCloud) {
          return 'CloudToLocalLLM - Local Connected\nLocal Ollama: $localEndpoint\nCloud Proxy: ${_connectionManager == null ? 'Not Available' : 'Disconnected'}';
        } else if (!hasLocal && hasCloud) {
          return 'CloudToLocalLLM - Cloud Connected\nLocal Ollama: Disconnected\nCloud Proxy: $cloudEndpoint';
        }
        return 'CloudToLocalLLM - Partially Connected';
      case TrayConnectionStatus.connecting:
        return 'CloudToLocalLLM - Connecting...';
      case TrayConnectionStatus.disconnected:
        return 'CloudToLocalLLM - Disconnected\nLocal Ollama: Disconnected\nCloud Proxy: ${_connectionManager == null ? 'Not Available' : 'Disconnected'}';
    }
  }

  /// Update context menu with current connection status
  Future<void> _updateContextMenu() async {
    try {
      appLogger.debug('[NativeTray] Updating context menu...');

      // Get current connection status for dynamic menu items
      String localStatus = 'Disconnected';
      String cloudStatus = 'Not Available';

      if (_localOllama?.isConnected == true) {
        localStatus = 'Connected';
      } else if (_localOllama?.isConnecting == true) {
        localStatus = 'Connecting...';
      }

      if (_connectionManager != null) {
        if (_connectionManager!.hasCloudConnection) {
          cloudStatus = 'Connected';
        } else {
          cloudStatus = 'Disconnected';
        }
      }

      final menu = Menu(
        items: [
          MenuItem(key: 'show', label: 'Show CloudToLocalLLM'),
          MenuItem(key: 'hide', label: 'Hide CloudToLocalLLM'),
          MenuItem.separator(),
          MenuItem(key: 'local_status', label: 'Local Ollama: $localStatus'),
          MenuItem(key: 'cloud_status', label: 'Cloud Proxy: $cloudStatus'),
          MenuItem.separator(),
          MenuItem(key: 'settings', label: 'Settings'),
          MenuItem(key: 'reconnect', label: 'Reconnect All'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      );

      await trayManager.setContextMenu(menu);
      appLogger.debug(
        '[NativeTray] Context menu updated successfully with ${menu.items?.length ?? 0} items',
      );
    } catch (e) {
      appLogger.error('[NativeTray] Failed to update context menu', error: e);
      rethrow; // Re-throw to allow caller to handle the error
    }
  }

  /// Dispose of the tray service
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      appLogger.debug('[NativeTray] Disposing native tray service...');

      // Remove listeners
      trayManager.removeListener(this);
      _connectionManager?.removeListener(_onTunnelStatusChanged);
      _localOllama?.removeListener(_onTunnelStatusChanged);
      await _statusSubscription?.cancel();
      _updateDebounceTimer?.cancel();

      // Destroy tray
      await trayManager.destroy();

      _isInitialized = false;
      appLogger.debug('[NativeTray] Native tray service disposed');
    } catch (e) {
      appLogger.error('[NativeTray] Error disposing native tray service',
          error: e);
    }
  }

  // TrayListener implementation

  @override
  void onTrayIconMouseDown() {
    appLogger.debug('[NativeTray] Tray icon clicked');
    _onShowWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    appLogger.debug('[NativeTray] Tray icon right-clicked');
    _showContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
    appLogger.debug('[NativeTray] Tray icon right-click released');
    // Fallback: if context menu wasn't shown on mouse down, try on mouse up
    // This helps with platform-specific timing issues
    _showContextMenu();
  }

  /// Explicitly show the context menu
  ///
  /// This method manually triggers the context menu display, which is necessary
  /// on Windows where the context menu doesn't automatically appear on right-click
  /// with tray_manager 0.5.0.
  Future<void> _showContextMenu() async {
    try {
      appLogger.debug('[NativeTray] Manually triggering context menu');
      await trayManager.popUpContextMenu();
      appLogger.debug('[NativeTray] Context menu displayed successfully');
    } catch (e) {
      appLogger.warning('[NativeTray] Failed to show context menu: $e');
      // Context menu failure is not critical - the user can still left-click to show the app
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    appLogger.debug('[NativeTray] Menu item clicked: ${menuItem.key}');

    switch (menuItem.key) {
      case 'show':
        _onShowWindow?.call();
        break;
      case 'hide':
        _onHideWindow?.call();
        break;
      case 'local_status':
      case 'cloud_status':
        // Status items are informational - show main window
        _onShowWindow?.call();
        break;
      case 'settings':
        _showSettings();
        break;
      case 'reconnect':
        _reconnectAll();
        break;
      case 'quit':
        _onQuit?.call();
        break;
    }
  }

  /// Reconnect all services
  void _reconnectAll() {
    appLogger.info('[NativeTray] Reconnecting all services');
    try {
      // Trigger reconnection through connection manager
      _connectionManager?.reconnectAll();

      // Update menu to show connecting status
      _updateContextMenu();
    } catch (e) {
      appLogger.error('[NativeTray] Failed to reconnect services', error: e);
    }
  }

  /// Show settings interface
  void _showSettings() {
    appLogger.debug('[NativeTray] Showing settings');
    // Bring window to foreground and navigate to settings
    _onShowWindow?.call();
    // The navigation will be handled by the main app
    _onSettings?.call();
  }

  /// Force update of tray status
  Future<void> updateStatus() async {
    if (_isInitialized) {
      _onTunnelStatusChanged();
    }
  }

  /// Update the connection manager when it becomes available after authentication
  void updateConnectionManager(ConnectionManagerService connectionManager) {
    if (!_isInitialized) return;

    appLogger.info('[NativeTray] Updating connection manager reference');

    // Remove old listener if exists
    if (_connectionManager != null) {
      _connectionManager!.removeListener(_onTunnelStatusChanged);
    }

    // Set new connection manager and add listener
    _connectionManager = connectionManager;
    _connectionManager!.addListener(_onTunnelStatusChanged);

    // Update tray status immediately
    _onTunnelStatusChanged();
  }
}
