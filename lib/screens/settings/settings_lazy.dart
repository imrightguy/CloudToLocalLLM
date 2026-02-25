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
    builder: (context, state) => const UnifiedSettingsScreen(),
  ),
  GoRoute(
    path: '/settings/downloads',
    name: 'settings-downloads',
    builder: (context, state) =>
        const UnifiedSettingsScreen(initialCategory: 'downloads'),
  ),
  GoRoute(
    path: '/settings/tunnel',
    name: 'tunnel-settings',
    builder: (context, state) =>
        const UnifiedSettingsScreen(initialCategory: 'tunnel-connection'),
  ),
  GoRoute(
    path: '/settings/daemon',
    name: 'daemon-settings',
    builder: (context, state) {
      debugPrint('[Router] Building DaemonSettingsScreen');
      return const DaemonSettingsScreen();
    },
  ),
  GoRoute(
    path: '/settings/connection-status',
    name: 'connection-status',
    builder: (context, state) {
      debugPrint('[Router] Building ConnectionStatusScreen');
      return const ConnectionStatusScreen();
    },
  ),
  GoRoute(
    path: '/upgrade',
    name: 'pricing',
    builder: (context, state) {
      debugPrint('[Router] Building PricingScreen');
      return const PricingScreen();
    },
  ),
  GoRoute(
    path: '/settings/avatar/customization',
    name: 'avatar-customization',
    builder: (context, state) {
      debugPrint('[Router] Building AvatarCustomizationScreen');
      return const AvatarCustomizationScreen();
    },
  ),
  GoRoute(
    path: '/settings/avatar',
    name: 'avatar-settings',
    builder: (context, state) {
      debugPrint('[Router] Building UnifiedSettingsScreen (avatar)');
      return const UnifiedSettingsScreen(initialCategory: 'avatar');
    },
  ),
  GoRoute(
    path: '/settings/desktop/files',
    name: 'desktop-file-operations',
    builder: (context, state) {
      debugPrint('[Router] Building FileOperationsScreen');
      return const FileOperationsScreen();
    },
  ),
];
