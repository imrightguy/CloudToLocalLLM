import 'dart:async';

import 'package:flutter/foundation.dart';

import '../di/locator.dart';

/// Data returned by [AppBootstrapper] after the core environment is ready.
class AppBootstrapData {
  AppBootstrapData({required this.isWeb, required this.supportsNativeShell});

  final bool isWeb;
  final bool supportsNativeShell;
}

/// Handles the one-time initialization that must occur before the widget tree
/// is built.  This ensures heavy setup only happens once at application start.
class AppBootstrapper {
  AppBootstrapper();

  Future<AppBootstrapData> load() async {
    try {
      debugPrint('[Bootstrapper] Starting bootstrap process...');

      debugPrint('[Bootstrapper] Setting up service locator...');
      await setupServiceLocator().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          debugPrint(
              '[Bootstrapper] Service locator setup timed out after 25s; continuing with degraded startup');
        },
      );
      debugPrint('[Bootstrapper] Service locator setup completed');

      debugPrint('[Bootstrapper] Bootstrap completed successfully');
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    } catch (e, stack) {
      debugPrint('[Bootstrapper] ERROR during bootstrap: $e');
      debugPrint('[Bootstrapper] Stack trace: $stack');

      // Re-throw to let the caller handle it
      rethrow;
    }
  }
}
