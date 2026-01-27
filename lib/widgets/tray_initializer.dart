import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/connection_manager_service.dart';
import '../services/local_ollama_connection_service.dart';
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
    if (_trayInitialized || kIsWeb) {
      return;
    }
    _trayInitialized = true;

    unawaited(_initializeTray(context));
  }

  Future<void> _initializeTray(BuildContext context) async {
    try {
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

      final localOllama = context.read<LocalOllamaConnectionService>();
      final windowManager = WindowManagerService();
      final nativeTray = NativeTrayService();

      await windowManager.initialize();

      final initialized = await nativeTray.initialize(
        connectionManager: connectionManager,
        localOllama: localOllama,
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
        onQuit: windowManager.forceClose,
      );

      if (!initialized) {
        appLogger.warning(
          '[TrayInitializer] Native tray initialization reported failure',
        );
      } else {
        appLogger
            .info('[TrayInitializer] Native tray initialized successfully');

        // Set up a listener to update the tray when ConnectionManagerService becomes available
        if (connectionManager == null) {
          _setupConnectionManagerListener(context, nativeTray);
        }
      }
    } catch (e, stackTrace) {
      appLogger.error(
        '[TrayInitializer] Failed to initialize tray',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Set up a listener to update the tray service when ConnectionManagerService becomes available
  void _setupConnectionManagerListener(
      BuildContext context, NativeTrayService nativeTray) {
    // Check periodically if ConnectionManagerService becomes available
    Timer.periodic(const Duration(seconds: 2), (timer) {
      try {
        final connectionManager =
            Provider.of<ConnectionManagerService>(context, listen: false);
        // ConnectionManagerService is available, update tray
        appLogger.info(
            '[TrayInitializer] ConnectionManagerService now available, updating tray');
        nativeTray.updateConnectionManager(connectionManager);
        timer.cancel();
      } catch (e) {
        // ConnectionManagerService still not available, continue checking
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
