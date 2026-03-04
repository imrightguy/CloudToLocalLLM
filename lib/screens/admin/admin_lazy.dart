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
    pageBuilder: (context, state) {
      debugPrint('[Router] Building AdminDataFlushScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const AdminDataFlushScreen(),
      );
    },
  ),
  GoRoute(
    path: '/admin-center',
    name: 'admin-center',
    pageBuilder: (context, state) {
      debugPrint('[Router] Building AdminCenterScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const AdminCenterScreen(),
      );
    },
  ),
];
