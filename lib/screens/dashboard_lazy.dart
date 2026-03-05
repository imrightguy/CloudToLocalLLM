import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dashboard/agent_detail_screen.dart';

// Lazy-loaded dashboard routes
// NOTE: /dashboard route removed - functionality moved to /overview in StatefulShellRoute
// NOTE: /agents route now handled by StatefulShellRoute branch index 7
final dashboardRoutes = [
  // Agent detail route (still needed for deep linking to specific agents)
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
