/// Test app wrapper utilities
///
/// Provides reusable widget wrappers for testing screens and widgets
/// with proper theme, platform, and service providers.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:cloudtolocalllm/config/theme.dart';
import 'mock_services.dart';

/// Wraps a widget with MaterialApp and theme providers for testing
class TestAppWrapper extends StatelessWidget {
  final Widget child;
  final ThemeProvider? themeProvider;
  final PlatformDetectionService? platformService;
  final PlatformAdapter? platformAdapter;
  final MockAuthService? authService;
  final MockAdminCenterService? adminService;
  final ThemeMode? themeMode;

  const TestAppWrapper({
    super.key,
    required this.child,
    this.themeProvider,
    this.platformService,
    this.platformAdapter,
    this.authService,
    this.adminService,
    this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeProvider ?? ThemeProvider();
    if (themeMode != null) {
      theme.setThemeMode(themeMode!);
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        if (platformService != null)
          Provider<PlatformDetectionService>.value(value: platformService!),
        if (platformAdapter != null)
          Provider<PlatformAdapter>.value(value: platformAdapter!),
        if (authService != null)
          ChangeNotifierProvider<MockAuthService>.value(value: authService!),
        if (adminService != null)
          ChangeNotifierProvider<MockAdminCenterService>.value(
            value: adminService!,
          ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: provider.themeMode,
            home: child,
          );
        },
      ),
    );
  }
}

/// Creates a minimal test app wrapper with just theme support
Widget createMinimalTestApp(Widget child, {ThemeMode? themeMode}) {
  return TestAppWrapper(
    themeMode: themeMode,
    child: child,
  );
}

/// Creates a test app wrapper with platform detection
Widget createPlatformTestApp(
  Widget child, {
  ThemeMode? themeMode,
  PlatformDetectionService? platformService,
}) {
  return TestAppWrapper(
    themeMode: themeMode,
    platformService: platformService ?? PlatformDetectionService(),
    platformAdapter: PlatformAdapter(
      platformService ?? PlatformDetectionService(),
    ),
    child: child,
  );
}

/// Creates a test app wrapper with authentication services
Widget createAuthenticatedTestApp(
  Widget child, {
  ThemeMode? themeMode,
  bool authenticated = true,
  PlatformDetectionService? platformService,
}) {
  final authService = createMockAuthService(authenticated: authenticated);
  final adminService = createMockAdminCenterService();

  return TestAppWrapper(
    themeMode: themeMode,
    platformService: platformService ?? PlatformDetectionService(),
    platformAdapter: PlatformAdapter(
      platformService ?? PlatformDetectionService(),
    ),
    authService: authService,
    adminService: adminService,
    child: child,
  );
}

/// Creates a full-featured test app wrapper with all services
Widget createFullTestApp(
  Widget child, {
  ThemeProvider? themeProvider,
  PlatformDetectionService? platformService,
  PlatformAdapter? platformAdapter,
  MockAuthService? authService,
  MockAdminCenterService? adminService,
  ThemeMode? themeMode,
}) {
  return TestAppWrapper(
    themeProvider: themeProvider,
    platformService: platformService ?? PlatformDetectionService(),
    platformAdapter: platformAdapter ??
        PlatformAdapter(platformService ?? PlatformDetectionService()),
    authService: authService ?? createMockAuthService(authenticated: true),
    adminService: adminService ?? createMockAdminCenterService(),
    themeMode: themeMode,
    child: child,
  );
}
