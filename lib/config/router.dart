import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../di/locator.dart';
import '../services/onboarding/setup_wizard_service.dart';

import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/callback_screen.dart';
import '../screens/onboarding/setup_wizard_screen.dart';

// Settings screens are lazy-loaded
import '../screens/settings/settings_lazy.dart' as settings_lazy;

// GUI Automation screen (lazy-loaded)
import '../screens/gui_automation_lazy.dart' as gui_automation_lazy;

// Admin screens (lazy-loaded)
import '../screens/admin/admin_lazy.dart' as admin_lazy;

// Agent status screen is lazy-loaded
import '../screens/agent_status_lazy.dart' as agent_status_lazy;

// Dashboard screens (lazy-loaded)
import '../screens/dashboard_lazy.dart' as dashboard_lazy;

// Marketing screens (web-only) are lazy-loaded
import '../screens/marketing/marketing_lazy.dart' as marketing_lazy;

// Construction screen (lazy-loaded)
import '../screens/construction_lazy.dart' as construction_lazy;

/// Utility function to get the current hostname in web environment
String _getCurrentHostname() {
  if (kIsWeb) {
    try {
      return Uri.base.host;
    } catch (e) {
      return '';
    }
  }
  return '';
}

/// Check if current hostname indicates app subdomain
bool _isAppSubdomain() {
  if (!kIsWeb) return false;

  final hostname = _getCurrentHostname();
  final isApp = hostname.startsWith('app.') ||
      hostname == 'app.cloudtolocalllm.online' ||
      hostname == 'localhost' ||
      hostname == '127.0.0.1';

  debugPrint('[Router] Hostname: $hostname, isApp: $isApp');
  return isApp;
}

/// Helper to check for Auth0 callback parameters
bool _hasCallbackParameters(Uri uri) {
  return uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('state') ||
      uri.queryParameters.containsKey('error') ||
      uri.queryParameters.containsKey('error_description');
}

/// Wrapper widget that checks if setup wizard is needed
/// and redirects to /setup if no providers are configured
class _HomeWithSetupCheck extends StatefulWidget {
  final bool isAuthenticated;

  const _HomeWithSetupCheck({
    required this.isAuthenticated,
  });

  @override
  State<_HomeWithSetupCheck> createState() => _HomeWithSetupCheckState();
}

class _HomeWithSetupCheckState extends State<_HomeWithSetupCheck> {
  @override
  void initState() {
    super.initState();
    _checkSetupNeeded();
  }

  Future<void> _checkSetupNeeded() async {
    if (!AppConfig.forceSetupWizard) {
      debugPrint('[Router] Setup wizard disabled, skipping check');
      return;
    }

    try {
      final setupWizardService = serviceLocator<SetupWizardService>();
      final shouldShow = await setupWizardService.shouldShowWizard();

      if (shouldShow && mounted) {
        debugPrint(
            '[Router] No providers configured, redirecting to setup wizard');
        if (mounted) {
          context.go('/setup');
        }
      }
    } catch (e) {
      debugPrint('[Router] Error checking setup status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

/// Application router configuration using GoRouter
class AppRouter {
  static GoRouter createRouter({
    GlobalKey<NavigatorState>? navigatorKey,
    required AuthService authService,
  }) {
    debugPrint('[Router] createRouter called');

    // For web, determine initial location thoughtfully
    String initialLocation = '/';
    if (kIsWeb) {
      final currentUri = Uri.base;
      if (_hasCallbackParameters(currentUri)) {
        debugPrint(
            '[Router] Initial URL has callback parameters, forcing /callback');
        initialLocation = '/callback?${currentUri.query}';
      } else {
        initialLocation = currentUri.path;
        if (currentUri.hasQuery) {
          initialLocation += '?${currentUri.query}';
        }
      }
    }
    debugPrint('[Router] Initial location: $initialLocation');

    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      refreshListenable: authService,
      routes: [
        // Home route
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) {
            debugPrint('[Router] Home pageBuilder triggered');

            // Failsafe for callback params
            if (kIsWeb &&
                (_hasCallbackParameters(state.uri) ||
                    _hasCallbackParameters(Uri.base))) {
              debugPrint(
                  '[Router] Failsafe: Redirecting to CallbackScreen in pageBuilder');
              final params = state.uri.queryParameters.isNotEmpty
                  ? state.uri.queryParameters
                  : Uri.base.queryParameters;
              return MaterialPage(
                key: state.pageKey,
                child: CallbackScreen(queryParams: params),
              );
            }

            final isAuthenticated = authService.isAuthenticated.value;

            if (isAuthenticated || !kIsWeb) {
              // Show home screen first, then check if setup is needed
              return MaterialPage(
                key: state.pageKey,
                child: _HomeWithSetupCheck(
                  isAuthenticated: isAuthenticated,
                ),
              );
            }

            if (kIsWeb && !_isAppSubdomain()) {
              return MaterialPage(
                key: state.pageKey,
                child: const marketing_lazy.HomepageScreen(),
              );
            }

            return MaterialPage(
              key: state.pageKey,
              child: const LoginScreen(),
            );
          },
        ),

        // Setup Wizard route
        GoRoute(
          path: '/setup',
          name: 'setup',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const SetupWizardScreen(),
          ),
        ),

        // Marketing & Other routes
        ...marketing_lazy.marketingRoutes,
        ...settings_lazy.settingsRoutes,
        ...admin_lazy.adminRoutes,
        ...agent_status_lazy.agentStatusRoutes,
        ...dashboard_lazy.dashboardRoutes,
        ...gui_automation_lazy.guiAutomationRoutes,
        ...construction_lazy.constructionRoutes,

        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const LoginScreen(),
          ),
        ),

        GoRoute(
          path: '/callback',
          name: 'callback',
          pageBuilder: (context, state) {
            if (!kIsWeb) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/login');
              });
              return MaterialPage(
                key: state.pageKey,
                child: Scaffold(
                    body: Center(child: CircularProgressIndicator())),
              );
            }

            final params = state.uri.queryParameters.isNotEmpty
                ? state.uri.queryParameters
                : Uri.base.queryParameters;
            return MaterialPage(
              key: state.pageKey,
              child: CallbackScreen(queryParams: params),
            );
          },
        ),
      ],
      redirect: (context, state) {
        debugPrint('[Router] Redirect check: ${state.matchedLocation}');

        final isAuthenticated = authService.isAuthenticated.value;
        final isAuthLoading = authService.isLoading.value;
        final isLoggingIn = state.matchedLocation == '/login';
        final isCallback = state.matchedLocation == '/callback';
        final isAppSubdomain = _isAppSubdomain();

        // 1. Handle auth callbacks first
        final hasCallbackParams = _hasCallbackParameters(state.uri) ||
            (kIsWeb && _hasCallbackParameters(Uri.base));
        if (hasCallbackParams && !isCallback && kIsWeb) {
          debugPrint('[Router] Redirecting to /callback to process params');
          final params = state.uri.queryParameters.isNotEmpty
              ? state.uri.queryParameters
              : Uri.base.queryParameters;
          return Uri(path: '/callback', queryParameters: params).toString();
        }

        // 2. While auth is loading, don't redirect unless necessary (e.g. away from callback if it's not a callback)
        if (isAuthLoading && !isCallback) return null;

        // 3. Marketing domain access
        if (kIsWeb && !isAppSubdomain) {
          if (isLoggingIn) return '/'; // Don't show login on marketing domain
          return null; // Allow all other routes (homepage, docs, etc.)
        }

        // 4. Authenticated state
        if (isAuthenticated) {
          if (isLoggingIn) return '/'; // Already logged in, go home
          return null; // Allow access
        }

        // 5. Unauthenticated state on App domain or Desktop
        if (isLoggingIn || isCallback || !kIsWeb) {
          return null; // Allow these (Desktop is always allowed)
        }

        // Redirect all other protected routes to login
        debugPrint(
            '[Router] Protected route ${state.matchedLocation} accessed, redirecting to login');
        return '/login';
      },
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Page Not Found', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
