import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'download_screen.dart';
import 'documentation_screen.dart';
import 'homepage_screen.dart';

// Re-export HomepageScreen for use in router.dart's home route
export 'homepage_screen.dart';

// This file contains the route configuration for the marketing screens,
// which will be lazy-loaded to improve initial application performance.

final marketingRoutes = [
  GoRoute(
    path: '/',
    name: 'homepage',
    pageBuilder: (context, state) {
      if (kIsWeb) {
        return MaterialPage(
          key: state.pageKey,
          child: const HomepageScreen(),
        );
      }

      return MaterialPage(
        key: state.pageKey,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Desktop App Required',
                    style: Theme.of(context).textTheme.headlineSmall),
                SizedBox(height: 8),
                Text(
                    'Please use the CloudToLocalLLM desktop application for the best experience.',
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    },
  ),
  GoRoute(
    path: '/index.html',
    name: 'homepage-index',
    pageBuilder: (context, state) {
      if (kIsWeb) {
        return MaterialPage(
          key: state.pageKey,
          child: const HomepageScreen(),
        );
      }

      return MaterialPage(
        key: state.pageKey,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Desktop App Required',
                    style: Theme.of(context).textTheme.headlineSmall),
                SizedBox(height: 8),
                Text(
                    'Please use the CloudToLocalLLM desktop application for the best experience.',
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    },
  ),
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
        // Desktop users should use the desktop app
        return MaterialPage(
          key: state.pageKey,
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Desktop App Required',
                      style: Theme.of(context).textTheme.headlineSmall),
                  SizedBox(height: 8),
                  Text(
                      'Please use the CloudToLocalLLM desktop application for the best experience.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
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
        // Desktop users should use the desktop app
        return MaterialPage(
          key: state.pageKey,
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Desktop App Required',
                      style: Theme.of(context).textTheme.headlineSmall),
                  SizedBox(height: 8),
                  Text(
                      'Please use the CloudToLocalLLM desktop application for the best experience.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }
    },
  ),
];
