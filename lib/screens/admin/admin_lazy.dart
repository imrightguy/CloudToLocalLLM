import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_center_screen.dart';
import 'admin_data_flush_screen.dart';

// This file contains the route configuration for the admin screens,
// which will be lazy-loaded to improve initial application performance.

final adminRoutes = [
  GoRoute(
    path: '/admin/data-flush',
    name: 'admin-data-flush',
    builder: (context, state) {
      debugPrint('[Router] Building AdminDataFlushScreen');
      return const AdminDataFlushScreen();
    },
  ),
  GoRoute(
    path: '/admin-center',
    name: 'admin-center',
    builder: (context, state) {
      debugPrint('[Router] Building AdminCenterScreen');
      return const AdminCenterScreen();
    },
  ),
];
