import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'agent_status_screen.dart';
import 'brain_insights_screen.dart';

// Lazy-loaded agent status routes
final agentStatusRoutes = [
  GoRoute(
    path: '/agent-status',
    name: 'agent-status',
    builder: (context, state) {
      debugPrint('[Router] Building AgentStatusScreen');
      return const AgentStatusScreen();
    },
  ),
  GoRoute(
    path: '/brain-insights',
    name: 'brain-insights',
    builder: (context, state) {
      debugPrint('[Router] Building BrainInsightsScreen');
      return const BrainInsightsScreen();
    },
  ),
];
