import 'dart:io' show exit;
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/logger.dart';

/// Service for managing window state and visibility using window_manager_plus
class WindowManagerService {
  static final WindowManagerService _instance =
      WindowManagerService._internal();
  factory WindowManagerService() => _instance;
  WindowManagerService._internal();

  bool _isWindowVisible = true;
  bool _isMinimizedToTray = false;
  bool _isInitialized = false;

  /// Initialize the window manager service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize window_manager if not on web
      if (!kIsWeb) {
        await windowManager.ensureInitialized();

        // Set minimum window size to prevent too small windows
        await windowManager.setMinimumSize(Size(1200, 800));

        // Check current window size and set initial if too small
        final size = await windowManager.getSize();
        if (size.width < 1200 || size.height < 800) {
          await windowManager.setSize(Size(1400, 900));
          await windowManager.center();
          appLogger
              .info('[WindowManager] Window resized to 1400x900 and centered');
        }

        await windowManager.setPreventClose(true);
        _isInitialized = true;
        appLogger.info('[WindowManager] Window manager service initialized');
      }
    } catch (e) {
      appLogger.error(
        '[WindowManager] Failed to initialize window manager',
        error: e,
      );
    }
  }

  /// Show the application window
  Future<void> showWindow() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.show();
        await windowManager.focus();
      }
      _isWindowVisible = true;
      _isMinimizedToTray = false;
      appLogger.debug('[WindowManager] Window shown');
    } catch (e) {
      appLogger.error('[WindowManager] Failed to show window', error: e);
    }
  }

  /// Hide the application window to system tray
  Future<void> hideToTray() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.hide();
      }
      _isWindowVisible = false;
      _isMinimizedToTray = true;
      appLogger.debug('[WindowManager] Window hidden to tray');
    } catch (e) {
      appLogger.error('[WindowManager] Failed to hide window', error: e);
    }
  }

  /// Minimize the window (but keep it in taskbar)
  Future<void> minimizeWindow() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.minimize();
      }
      _isWindowVisible = false;
      _isMinimizedToTray = false;
      appLogger.debug('[WindowManager] Window minimized');
    } catch (e) {
      appLogger.error('[WindowManager] Failed to minimize window', error: e);
    }
  }

  /// Maximize the window
  Future<void> maximizeWindow() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.maximize();
      }
      _isWindowVisible = true;
      _isMinimizedToTray = false;
      appLogger.debug('[WindowManager] Window maximized');
    } catch (e) {
      appLogger.error('[WindowManager] Failed to maximize window', error: e);
    }
  }

  /// Toggle window visibility
  Future<void> toggleWindow() async {
    if (_isWindowVisible) {
      await hideToTray();
    } else {
      await showWindow();
    }
  }

  /// Force close the application (for quit functionality)
  Future<void> forceClose() async {
    try {
      if (!kIsWeb && _isInitialized) {
        appLogger.warning('[WindowManager] Initiating force close sequence');

        // Disable close prevention
        await windowManager.setPreventClose(false);

        // Try to close the window gracefully first
        await windowManager.close();

        // If that doesn't work, destroy the window
        await Future.delayed(const Duration(milliseconds: 100));
        await windowManager.destroy();

        // As a last resort, exit the process
        await Future.delayed(const Duration(milliseconds: 100));
        if (!kIsWeb) {
          exit(0);
        }
      }
      appLogger.info('[WindowManager] Application force closed');
    } catch (e) {
      appLogger.error('[WindowManager] Failed to force close', error: e);
      // Emergency exit if all else fails
      if (!kIsWeb) {
        try {
          exit(1);
        } catch (exitError) {
          appLogger.error(
            '[WindowManager] Emergency exit failed',
            error: exitError,
          );
        }
      }
    }
  }

  /// Check if window is currently visible
  bool get isWindowVisible => _isWindowVisible;

  /// Check if window is minimized to tray
  bool get isMinimizedToTray => _isMinimizedToTray;

  /// Check if window manager is initialized
  bool get isInitialized => _isInitialized;

  /// Set window visibility state (for internal tracking)
  void setWindowVisible(bool visible) {
    _isWindowVisible = visible;
    if (visible) {
      _isMinimizedToTray = false;
    }
  }

  /// Handle window close event (should minimize to tray instead of closing)
  Future<bool> handleWindowClose() async {
    try {
      await hideToTray();
      appLogger.debug(
        '[WindowManager] Window close intercepted, minimized to tray',
      );
      return false; // Prevent actual window close
    } catch (e) {
      // GTK window may already be partially destroyed (Niri/Wayland).
      // Set state manually and hard-prevent the close.
      appLogger.warning(
        '[WindowManager] hideToTray failed, forcing close prevention: $e',
      );
      _isWindowVisible = false;
      _isMinimizedToTray = true;
      return false; // Still prevent close — keep the process alive
    }
  }

  /// Dispose of the window manager service
  void dispose() {
    appLogger.debug('[WindowManager] Window manager service disposed');
  }
}
