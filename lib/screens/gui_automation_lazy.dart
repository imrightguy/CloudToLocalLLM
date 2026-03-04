// Lazy loader for GUI Automation screen
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'gui_automation_screen.dart';

/// GUI Automation routes
List<RouteBase> get guiAutomationRoutes {
  return [
    GoRoute(
      path: '/gui-automation',
      name: 'gui-automation',
      pageBuilder: (context, state) {
        return MaterialPage(
          key: state.pageKey,
          child: const GuiAutomationScreen(),
        );
      },
    ),
  ];
}
