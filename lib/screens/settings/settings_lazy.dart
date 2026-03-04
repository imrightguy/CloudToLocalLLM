import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'unified_settings_screen.dart';
import 'daemon_settings_screen.dart';
import 'connection_status_screen.dart';
import 'pricing_screen.dart';
import '../avatar/avatar_customization_screen.dart';
import '../desktop/file_operations_screen.dart';

// This file contains the route configuration for the settings screens,
// which will be lazy-loaded to improve initial application performance.

final settingsRoutes = [
  GoRoute(
    path: '/settings',
    name: 'settings',
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: const UnifiedSettingsScreen(),
    ),
  ),
  GoRoute(
    path: '/settings/downloads',
    name: 'settings-downloads',
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: const UnifiedSettingsScreen(initialCategory: 'downloads'),
    ),
  ),
  GoRoute(
    path: '/settings/tunnel',
    name: 'tunnel-settings',
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: const UnifiedSettingsScreen(initialCategory: 'tunnel-connection'),
    ),
  ),
  GoRoute(
    path: '/settings/daemon',
    name: 'daemon-settings',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building DaemonSettingsScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const DaemonSettingsScreen(),
      );
    },
  ),
  GoRoute(
    path: '/settings/connection-status',
    name: 'connection-status',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building ConnectionStatusScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const ConnectionStatusScreen(),
      );
    },
  ),
  GoRoute(
    path: '/upgrade',
    name: 'pricing',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building PricingScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const PricingScreen(),
      );
    },
  ),
  GoRoute(
    path: '/settings/avatar/customization',
    name: 'avatar-customization',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building AvatarCustomizationScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const AvatarCustomizationScreen(),
      );
    },
  ),
  GoRoute(
    path: '/settings/avatar',
    name: 'avatar-settings',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building UnifiedSettingsScreen (avatar)');
      return MaterialPage(
        key: state.pageKey,
        child: const UnifiedSettingsScreen(initialCategory: 'avatar'),
      );
    },
  ),
  GoRoute(
    path: '/settings/desktop/files',
    name: 'desktop-file-operations',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building FileOperationsScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const FileOperationsScreen(),
      );
    },
  ),
];
