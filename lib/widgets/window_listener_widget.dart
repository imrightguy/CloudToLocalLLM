import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import '../services/window_manager_service.dart';

/// Widget that listens to window events and handles them appropriately
class WindowListenerWidget extends StatefulWidget {
  final Widget child;

  const WindowListenerWidget({super.key, required this.child});

  @override
  State<WindowListenerWidget> createState() => _WindowListenerWidgetState();
}

class _WindowListenerWidgetState extends State<WindowListenerWidget>
    with WindowListener {
  final WindowManagerService _windowManager = WindowManagerService();

  @override
  void initState() {
    super.initState();
    _initializeWindowListener();
  }

  Future<void> _initializeWindowListener() async {
    if (!kIsWeb) {
      try {
        // Initialize window manager service
        await _windowManager.initialize();

        // Add this widget as a window listener
        windowManager.addListener(this);

        debugPrint(' [WindowListener] Window listener initialized');
      } catch (e) {
        debugPrint(
          ' [WindowListener] Failed to initialize window listener: $e',
        );
      }
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      try {
        windowManager.removeListener(this);
        debugPrint(' [WindowListener] Window listener disposed');
      } catch (e) {
        debugPrint(' [WindowListener] Failed to dispose window listener: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  // WindowListener implementation

  @override
  void onWindowClose([int? windowId]) async {
    debugPrint(' [WindowListener] Window close event received');

    // Handle the close event through the window manager service
    final shouldClose = await _windowManager.handleWindowClose();

    if (shouldClose) {
      // If we should actually close, allow it
      debugPrint(' [WindowListener] Allowing window to close');
    } else {
      // Window was minimized to tray instead
      debugPrint(
        ' [WindowListener] Window minimized to tray instead of closing',
      );
    }
  }

  @override
  void onWindowFocus([int? windowId]) {
    debugPrint(' [WindowListener] Window gained focus');
    _windowManager.setWindowVisible(true);
  }

  @override
  void onWindowBlur([int? windowId]) {
    debugPrint(' [WindowListener] Window lost focus');
  }

  @override
  void onWindowMaximize([int? windowId]) {
    debugPrint(' [WindowListener] Window maximized');
    _windowManager.setWindowVisible(true);
  }

  @override
  void onWindowUnmaximize([int? windowId]) {
    debugPrint(' [WindowListener] Window unmaximized');
  }

  @override
  void onWindowMinimize([int? windowId]) {
    debugPrint(' [WindowListener] Window minimized');
    _windowManager.setWindowVisible(false);
  }

  @override
  void onWindowRestore([int? windowId]) {
    debugPrint(' [WindowListener] Window restored');
    _windowManager.setWindowVisible(true);
  }

  @override
  void onWindowResize([int? windowId]) {
    // Don't log resize events as they're frequent
  }

  @override
  void onWindowMove([int? windowId]) {
    // Don't log move events as they're frequent
  }

  @override
  void onWindowEnterFullScreen([int? windowId]) {
    debugPrint(' [WindowListener] Window entered fullscreen');
  }

  @override
  void onWindowLeaveFullScreen([int? windowId]) {
    debugPrint(' [WindowListener] Window left fullscreen');
  }

  @override
  void onWindowEvent(String eventName, [int? windowId]) {
    debugPrint(' [WindowListener] Window event: $eventName');
  }
}
