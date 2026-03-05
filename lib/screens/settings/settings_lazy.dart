import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'daemon_settings_screen.dart';
import 'connection_status_screen.dart';
import 'pricing_screen.dart';
import '../avatar/avatar_customization_screen.dart';
import '../desktop/file_operations_screen.dart';

// Individual category screens
import 'general_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'connection_settings_screen.dart';
import 'avatar_settings_screen.dart';
import 'desktop_settings_screen.dart';
import 'about_settings_screen.dart';

// This file contains the route configuration for the settings screens,
// which will be lazy-loaded to improve initial application performance.
//
// NOTE: The main /settings route that used UnifiedSettingsScreen has been removed.
// Settings navigation is now integrated into the sidebar (Config, Debug, Logs branches).
// These routes remain for deep linking and direct access to specific settings categories.

final settingsRoutes = [
  // Settings category routes (for deep linking)
  GoRoute(
    path: '/settings/general',
    name: 'settings-general',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building GeneralSettingsScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const GeneralSettingsScreen(),
      );
    },
  ),

  GoRoute(
    path: '/settings/appearance',
    name: 'settings-appearance',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building AppearanceSettingsScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const AppearanceSettingsScreen(),
      );
    },
  ),

  GoRoute(
    path: '/settings/connection',
    name: 'settings-connection',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building ConnectionSettingsScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const ConnectionSettingsScreen(),
      );
    },
  ),

  GoRoute(
    path: '/settings/avatar',
    name: 'settings-avatar',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building AvatarSettingsScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const AvatarSettingsScreen(),
      );
    },
  ),

  GoRoute(
    path: '/settings/desktop',
    name: 'settings-desktop',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building DesktopSettingsScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const DesktopSettingsScreen(),
      );
    },
  ),

  GoRoute(
    path: '/settings/about',
    name: 'settings-about',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building AboutSettingsScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const AboutSettingsScreen(),
      );
    },
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
