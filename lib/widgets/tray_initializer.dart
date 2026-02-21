import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/connection_manager_service.dart';
import '../services/native_tray_service.dart'
    if (dart.library.html) '../services/native_tray_service_stub.dart';
import '../services/window_manager_service.dart'
    if (dart.library.html) '../services/window_manager_service_stub.dart';
import '../utils/logger.dart';

/// Ensures the native tray is configured once all required providers exist.
/// Enhanced with improved error handling and resource monitoring.
class TrayInitializer extends StatefulWidget {
  const TrayInitializer({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<TrayInitializer> createState() => _TrayInitializerState();
}

class _TrayInitializerState extends State<TrayInitializer> {
  bool _trayInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appLogger.info('[TrayInitializer] didChangeDependencies called');
    if (_trayInitialized || kIsWeb) {
      appLogger.info('[TrayInitializer] Already initialized or web, skipping');
      return;
    }
    _trayInitialized = true;

    appLogger.info('[TrayInitializer] Starting async tray init...');
    unawaited(_initializeTray(context));
    appLogger.info('[TrayInitializer] Tray init scheduled');
  }

  Future<void> _initializeTray(BuildContext context) async {
    try {
      appLogger.info('[TrayInitializer] Starting tray initialization...');

      // ConnectionManagerService is an authenticated service that may not be available yet
      // Use Provider.of with listen: false to safely check if it's available
      ConnectionManagerService? connectionManager;
      try {
        connectionManager =
            Provider.of<ConnectionManagerService>(context, listen: false);
      } catch (e) {
        appLogger.info(
            '[TrayInitializer] ConnectionManagerService not available yet (user not authenticated)');
        connectionManager = null;
      }

      final windowManager = WindowManagerService();
      final nativeTray = NativeTrayService();

      appLogger.info('[TrayInitializer] Initializing window manager...');
      await windowManager.initialize();
      appLogger.info('[TrayInitializer] Window manager initialized');

      appLogger.info('[TrayInitializer] Initializing native tray...');
      final initialized = await nativeTray.initialize(
        connectionManager: connectionManager,
        onShowWindow: windowManager.showWindow,
        onHideWindow: windowManager.hideToTray,
        onSettings: () {
          final context = widget.navigatorKey.currentContext;
          if (context != null) {
            GoRouter.of(context).go('/settings');
          } else {
            appLogger.warning(
              '[TrayInitializer] Unable to navigate to settings: no context from navigatorKey',
            );
          }
        },
        onQuit: () async {
          appLogger.info('[TrayInitializer] Quit requested from tray');
          await windowManager.forceClose();
        },
      );
      appLogger.info('[TrayInitializer] Native tray initialized: $initialized');

      if (initialized) {
        appLogger.info('[TrayInitializer] Native tray initialized');
      } else {
        appLogger.info(
            '[TrayInitializer] Native tray not supported on this platform');
      }
    } catch (e, st) {
      appLogger.error('[TrayInitializer] Tray init failed',
          error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    appLogger.info('[TrayInitializer] build() called');
    return widget.child;
  }
}
