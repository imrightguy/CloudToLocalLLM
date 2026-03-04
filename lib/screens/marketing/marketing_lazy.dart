import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'download_screen.dart';
import 'documentation_screen.dart';
import '../home_screen.dart';

// Re-export HomepageScreen for use in router.dart's home route
export 'homepage_screen.dart';

// This file contains the route configuration for the marketing screens,
// which will be lazy-loaded to improve initial application performance.

final marketingRoutes = [
  GoRoute(
    path: '/download',
    name: 'download',
    pageBuilder: (context, state) {
      // Only available on web platform
      if (kIsWeb) {
        return MaterialPage(
          key: state.pageKey,
          child: const DownloadScreen(),
        );
      } else {
        // Redirect desktop users to main app
        return MaterialPage(
          key: state.pageKey,
          child: const HomeScreen(),
        );
      }
    },
  ),
  GoRoute(
    path: '/docs',
    name: 'docs',
    pageBuilder: (context, state) {
      // Only available on web platform
      if (kIsWeb) {
        return MaterialPage(
          key: state.pageKey,
          child: const DocumentationScreen(),
        );
      } else {
        // Redirect desktop users to main app
        return MaterialPage(
          key: state.pageKey,
          child: const HomeScreen(),
        );
      }
    },
  ),
];
