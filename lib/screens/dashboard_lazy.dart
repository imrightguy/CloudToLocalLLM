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
    builder: (context, state) {
      debugPrint('[Router] Building DashboardScreen');
      return const DashboardScreen();
    },
  ),
  GoRoute(
    path: '/agents',
    name: 'agents',
    builder: (context, state) {
      debugPrint('[Router] Building AgentListView');
      return const AgentListView();
    },
  ),
  GoRoute(
    path: '/agents/:id',
    name: 'agent-detail',
    builder: (context, state) {
      final agentId = state.pathParameters['id'] ?? '';
      debugPrint('[Router] Building AgentDetailScreen for: $agentId');
      return AgentDetailScreen(agentId: agentId);
    },
  ),
];
