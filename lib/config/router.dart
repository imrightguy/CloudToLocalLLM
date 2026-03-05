import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/streaming_chat_service.dart';
import '../di/locator.dart';
import '../services/onboarding/setup_wizard_service.dart';

import '../screens/login_screen.dart';
import '../screens/callback_screen.dart';
import '../screens/onboarding/setup_wizard_screen.dart';
import '../screens/home/home_layout.dart';
import '../widgets/navigation/openclaw_navigation_shell.dart';

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

// Overview screen
import '../screens/dashboard/overview_screen.dart';

// Channels screen
import '../screens/channels/channels_screen.dart';

// Placeholder screens - to be implemented in subsequent tasks
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String route;

  const PlaceholderScreen({required this.title, required this.route, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Route: $route', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            Text(
              'This screen will be implemented in a subsequent task.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper widget that provides HomeLayout with its required dependencies
class _HomeLayoutWrapper extends StatefulWidget {
  const _HomeLayoutWrapper();

  @override
  State<_HomeLayoutWrapper> createState() => _HomeLayoutWrapperState();
}

class _HomeLayoutWrapperState extends State<_HomeLayoutWrapper> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSendMessage(StreamingChatService service, String message) {
    service.sendMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    return HomeLayout(
      isCompact: false,
      scrollController: _scrollController,
      onSendMessage: _handleSendMessage,
    );
  }
}

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
  final Widget child;

  const _HomeWithSetupCheck({
    required this.child,
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
    return widget.child;
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

    final rootNavigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      refreshListenable: authService,
      routes: [
        // Setup Wizard route (must be before shell route)
        GoRoute(
          path: '/setup',
          name: 'setup',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const SetupWizardScreen(),
          ),
        ),

        // Main app with StatefulShellRoute for indexed navigation
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return _HomeWithSetupCheck(
              child: OpenClawNavigationShell(navigationShell: navigationShell),
            );
          },
          branches: [
            // Chat (branch index 0)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const _HomeLayoutWrapper(),
                  ),
                ),
              ],
            ),
            // Overview (branch index 1)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/overview',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const OverviewScreen(),
                  ),
                ),
              ],
            ),
            // Channels (branch index 2)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/channels',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const ChannelsScreen(),
                  ),
                ),
              ],
            ),
            // Instances (branch index 3)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/instances',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Instances',
                      route: '/instances',
                    ),
                  ),
                ),
              ],
            ),
            // Sessions (branch index 4)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/sessions',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Sessions',
                      route: '/sessions',
                    ),
                  ),
                ),
              ],
            ),
            // Usage (branch index 5)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/usage',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Usage',
                      route: '/usage',
                    ),
                  ),
                ),
              ],
            ),
            // Cron Jobs (branch index 6)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cron',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Cron Jobs',
                      route: '/cron',
                    ),
                  ),
                ),
              ],
            ),
            // Agents (branch index 7)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/agents',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Agents',
                      route: '/agents',
                    ),
                  ),
                ),
              ],
            ),
            // Skills (branch index 8)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/skills',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Skills',
                      route: '/skills',
                    ),
                  ),
                ),
              ],
            ),
            // Nodes (branch index 9)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/nodes',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Nodes',
                      route: '/nodes',
                    ),
                  ),
                ),
              ],
            ),
            // Config (branch index 10)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/config',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Config',
                      route: '/config',
                    ),
                  ),
                ),
              ],
            ),
            // Debug (branch index 11)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/debug',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Debug',
                      route: '/debug',
                    ),
                  ),
                ),
              ],
            ),
            // Logs (branch index 12)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/logs',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PlaceholderScreen(
                      title: 'Logs',
                      route: '/logs',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Login route
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const LoginScreen(),
          ),
        ),

        // Callback route
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

        // Marketing & Other routes
        ...marketing_lazy.marketingRoutes,
        ...settings_lazy.settingsRoutes,
        ...admin_lazy.adminRoutes,
        ...agent_status_lazy.agentStatusRoutes,
        ...dashboard_lazy.dashboardRoutes,
        ...gui_automation_lazy.guiAutomationRoutes,
        ...construction_lazy.constructionRoutes,
      ],
      redirect: (context, state) {
        debugPrint('[Router] Redirect check: ${state.matchedLocation}');

        final isAuthenticated = authService.isAuthenticated.value;
        final isAuthLoading = authService.isLoading.value;
        final location = state.matchedLocation;
        final isLoggingIn = location == '/login';
        final isCallback = location == '/callback';
        final isSetup = location == '/setup';
        final isAppSubdomain = _isAppSubdomain();
        final isShellRoute = location.startsWith('/chat') ||
            location.startsWith('/overview') ||
            location.startsWith('/channels') ||
            location.startsWith('/instances') ||
            location.startsWith('/sessions') ||
            location.startsWith('/usage') ||
            location.startsWith('/cron') ||
            location.startsWith('/agents') ||
            location.startsWith('/skills') ||
            location.startsWith('/nodes') ||
            location.startsWith('/config') ||
            location.startsWith('/debug') ||
            location.startsWith('/logs');

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

        // 2. While auth is loading, don't redirect unless necessary
        if (isAuthLoading && !isCallback && !isSetup) return null;

        // 3. Marketing domain access
        if (kIsWeb && !isAppSubdomain) {
          if (location == '/') return null; // Show marketing homepage
          if (isLoggingIn) return '/'; // Don't show login on marketing domain
          return null; // Allow all other routes (homepage, docs, etc.)
        }

        // 4. Handle root route redirect
        if (location == '/') {
          if (isAuthenticated || !kIsWeb) {
            // Redirect to chat as default home
            return '/chat';
          }
          return null; // Let marketing/home logic handle it
        }

        // 5. Authenticated state
        if (isAuthenticated) {
          if (isLoggingIn) return '/chat'; // Already logged in, go to chat
          return null; // Allow access to all routes
        }

        // 6. Unauthenticated state on App domain or Desktop
        if (isLoggingIn || isCallback || isSetup || !kIsWeb) {
          return null; // Allow these (Desktop is always allowed)
        }

        // 7. Redirect protected shell routes to login
        if (isShellRoute) {
          debugPrint(
              '[Router] Protected route $location accessed, redirecting to login');
          return '/login';
        }

        return null; // Allow all other routes
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
