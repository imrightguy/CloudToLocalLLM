import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dashboard/dashboard_screen.dart';
import 'dashboard/agent_list_view.dart';
import 'dashboard/agent_detail_screen.dart';

// Lazy-loaded dashboard routes
final dashboardRoutes = [
  GoRoute(
    path: '/dashboard',
    name: 'dashboard',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building DashboardScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const DashboardScreen(),
      );
    },
  ),
  GoRoute(
    path: '/agents',
    name: 'agents',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building AgentListView');
      return MaterialPage(
        key: state.pageKey,
        child: const AgentListView(),
      );
    },
  ),
  GoRoute(
    path: '/agents/:id',
    name: 'agent-detail',
    pageBuilder: (context, state) {
      final agentId = state.pathParameters['id'] ?? '';
      debugPrint('[Router] Building AgentDetailScreen for: $agentId');
      return MaterialPage(
        key: state.pageKey,
        child: AgentDetailScreen(agentId: agentId),
      );
    },
  ),
];
