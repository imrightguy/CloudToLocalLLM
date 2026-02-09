// Lazy loader for GUI Automation screen
import 'package:go_router/go_router.dart';

import 'gui_automation_screen.dart';

/// GUI Automation routes
List<RouteBase> get guiAutomationRoutes {
  return [
    GoRoute(
      path: '/gui-automation',
      name: 'gui-automation',
      builder: (context, state) {
        return const GuiAutomationScreen();
      },
    ),
  ];
}
