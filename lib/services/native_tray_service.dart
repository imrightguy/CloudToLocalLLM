import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'connection_manager_service.dart';
import 'local_ollama_connection_service.dart';
import 'tunnel_manager_service.dart';
import 'streaming_service.dart';

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
  TunnelManagerService? _tunnelManager;
  StreamSubscription<ConnectionStatusEvent>? _statusSubscription;

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
    required ConnectionManagerService connectionManager,
    required LocalOllamaConnectionService localOllama,
    required TunnelManagerService tunnelManager,
    void Function()? onShowWindow,
    void Function()? onHideWindow,
    void Function()? onSettings,
    void Function()? onQuit,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint('🖥️ [NativeTray] Initializing native tray service...');

      // Check platform support
      _isSupported = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
      if (!_isSupported) {
        debugPrint(
          '🖥️ [NativeTray] System tray not supported on this platform',
        );
        return false;
      }

      // Store references
      _connectionManager = connectionManager;
      _localOllama = localOllama;
      _tunnelManager = tunnelManager;
      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onSettings = onSettings;
      _onQuit = onQuit;

      // Initialize tray manager with basic setup first
      await trayManager.setIcon(
        _getIconPath(TrayConnectionStatus.disconnected),
      );

      // Set up context menu first (this is more reliable)
      await _updateContextMenu();

      // Add listener for tray events
      trayManager.addListener(this);

      // Listen to connection manager status changes
      _connectionManager!.addListener(_onTunnelStatusChanged);
      _localOllama!.addListener(_onTunnelStatusChanged);
      _tunnelManager!.addListener(_onTunnelStatusChanged);

      // Listen to streaming status events
      _setupStreamingStatusListener();

      // Try to set tooltip after other initialization (this might fail)
      try {
        await trayManager.setToolTip('CloudToLocalLLM - Initializing');
      } catch (e) {
        debugPrint('🖥️ [NativeTray] Warning: Could not set tooltip: $e');
        // Continue without tooltip - this is not critical
      }

      _isInitialized = true;
      debugPrint(
        '🖥️ [NativeTray] Native tray service initialized successfully',
      );

      // Update initial status
      _onTunnelStatusChanged();

      return true;
    } catch (e) {
      debugPrint(
        '🖥️ [NativeTray] Failed to initialize native tray service: $e',
      );
      // Don't fail the entire application if tray initialization fails
      return false;
    }
  }

  /// Setup streaming status event listener
  void _setupStreamingStatusListener() {
    _statusSubscription?.cancel();
    _statusSubscription = StatusEventBus().statusStream.listen(
      (event) {
        debugPrint('🖥️ [NativeTray] Received streaming status event: $event');
        // Update tray status when streaming events occur
        _onTunnelStatusChanged();
      },
      onError: (error) {
        debugPrint('🖥️ [NativeTray] Streaming status listener error: $error');
      },
    );
  }

  /// Handle connection status changes from all services
  void _onTunnelStatusChanged() {
    if (!_isInitialized || _connectionManager == null) return;

    final status = _getOverallConnectionStatus();
    _updateTrayIcon(status);
    _updateTooltip(status);
    _updateContextMenu(); // Update menu with current status
  }

  /// Get overall connection status from all services
  TrayConnectionStatus _getOverallConnectionStatus() {
    if (_connectionManager == null ||
        _localOllama == null ||
        _tunnelManager == null) {
      return TrayConnectionStatus.disconnected;
    }

    final hasLocal = _localOllama!.isConnected;
    final hasCloud = _tunnelManager!.isConnected;
    final isConnecting =
        _localOllama!.isConnecting || _tunnelManager!.isConnecting;

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
      debugPrint('🖥️ [NativeTray] Failed to update tray icon: $e');
    }
  }

  /// Update tooltip based on connection status
  Future<void> _updateTooltip(TrayConnectionStatus status) async {
    try {
      final tooltip = _getTooltipText(status);
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      debugPrint('🖥️ [NativeTray] Warning: Could not update tooltip: $e');
      // Tooltip updates are not critical for functionality
    }
  }

  /// Get icon path for connection status
  String _getIconPath(TrayConnectionStatus status) {
    switch (status) {
      case TrayConnectionStatus.allConnected:
        return 'assets/images/tray_icon_connected.png';
      case TrayConnectionStatus.partiallyConnected:
        return 'assets/images/tray_icon_partial.png';
      case TrayConnectionStatus.connecting:
        return 'assets/images/tray_icon_connecting.png';
      case TrayConnectionStatus.disconnected:
        return 'assets/images/tray_icon_disconnected.png';
    }
  }

  /// Get tooltip text for connection status
  String _getTooltipText(TrayConnectionStatus status) {
    if (_connectionManager == null ||
        _localOllama == null ||
        _tunnelManager == null) {
      return 'CloudToLocalLLM - Initializing';
    }

    final hasLocal = _localOllama!.isConnected;
    final hasCloud = _tunnelManager!.isConnected;
    final localEndpoint = 'http://localhost:11434';
    final cloudEndpoint = _tunnelManager!.config.cloudProxyUrl;

    switch (status) {
      case TrayConnectionStatus.allConnected:
        return 'CloudToLocalLLM - All Connected\nLocal Ollama: $localEndpoint\nCloud Proxy: $cloudEndpoint';
      case TrayConnectionStatus.partiallyConnected:
        if (hasLocal && !hasCloud) {
          return 'CloudToLocalLLM - Local Connected\nLocal Ollama: $localEndpoint\nCloud Proxy: Disconnected';
        } else if (!hasLocal && hasCloud) {
          return 'CloudToLocalLLM - Cloud Connected\nLocal Ollama: Disconnected\nCloud Proxy: $cloudEndpoint';
        }
        return 'CloudToLocalLLM - Partially Connected';
      case TrayConnectionStatus.connecting:
        return 'CloudToLocalLLM - Connecting...';
      case TrayConnectionStatus.disconnected:
        return 'CloudToLocalLLM - Disconnected\nLocal Ollama: Disconnected\nCloud Proxy: Disconnected';
    }
  }

  /// Update context menu with current connection status
  Future<void> _updateContextMenu() async {
    try {
      // Get current connection status for dynamic menu items
      String localStatus = 'Disconnected';
      String cloudStatus = 'Disconnected';

      if (_localOllama?.isConnected == true) {
        localStatus = 'Connected';
      } else if (_localOllama?.isConnecting == true) {
        localStatus = 'Connecting...';
      }

      if (_tunnelManager?.isConnected == true) {
        cloudStatus = 'Connected';
      } else if (_tunnelManager?.isConnecting == true) {
        cloudStatus = 'Connecting...';
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
    } catch (e) {
      debugPrint('🖥️ [NativeTray] Failed to update context menu: $e');
    }
  }

  /// Dispose of the tray service
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      debugPrint('🖥️ [NativeTray] Disposing native tray service...');

      // Remove listeners
      trayManager.removeListener(this);
      _connectionManager?.removeListener(_onTunnelStatusChanged);
      _localOllama?.removeListener(_onTunnelStatusChanged);
      _tunnelManager?.removeListener(_onTunnelStatusChanged);
      _statusSubscription?.cancel();

      // Destroy tray
      await trayManager.destroy();

      _isInitialized = false;
      debugPrint('🖥️ [NativeTray] Native tray service disposed');
    } catch (e) {
      debugPrint('🖥️ [NativeTray] Error disposing native tray service: $e');
    }
  }

  // TrayListener implementation

  @override
  void onTrayIconMouseDown() {
    debugPrint('🖥️ [NativeTray] Tray icon clicked');
    _onShowWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    debugPrint('🖥️ [NativeTray] Tray icon right-clicked');
    // Context menu will be shown automatically
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('🖥️ [NativeTray] Menu item clicked: ${menuItem.key}');

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
    debugPrint('🖥️ [NativeTray] Reconnecting all services');
    try {
      // Trigger reconnection through connection manager
      _connectionManager?.reconnectAll();

      // Update menu to show connecting status
      _updateContextMenu();
    } catch (e) {
      debugPrint('🖥️ [NativeTray] Failed to reconnect services: $e');
    }
  }

  /// Show settings interface
  void _showSettings() {
    debugPrint('🖥️ [NativeTray] Showing settings');
    // Bring window to foreground and navigate to settings
    _onShowWindow?.call();
    // The navigation will be handled by the main app
    _onSettings?.call();
  }

  /// Force update of tray status
  Future<void> updateStatus() async {
    if (_isInitialized && _tunnelManager != null) {
      _onTunnelStatusChanged();
    }
  }
}
