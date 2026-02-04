import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/callback_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

// Settings screens are lazy-loaded
import '../screens/settings/settings_lazy.dart' as settings_lazy;

// Admin screens are lazy-loaded
import '../screens/admin/admin_lazy.dart' as admin_lazy;

// Marketing screens (web-only) are lazy-loaded
import '../screens/marketing/marketing_lazy.dart' as marketing_lazy;

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
      hostname == 'app.zoidbot.online' ||
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
          builder: (context, state) {
            debugPrint('[Router] Home builder triggered');

            // Failsafe for callback params
            if (kIsWeb &&
                (_hasCallbackParameters(state.uri) ||
                    _hasCallbackParameters(Uri.base))) {
              debugPrint(
                  '[Router] Failsafe: Redirecting to CallbackScreen in builder');
              final params = state.uri.queryParameters.isNotEmpty
                  ? state.uri.queryParameters
                  : Uri.base.queryParameters;
              return CallbackScreen(queryParams: params);
            }

            final isAuthenticated = authService.isAuthenticated.value;
            final isAppDomain = _isAppSubdomain();

            if (isAuthenticated) return const HomeScreen();

            if (kIsWeb && !isAppDomain) {
              return const marketing_lazy.HomepageScreen();
            }

            // ALLOW HOME SCREEN WITHOUT AUTH
            return const HomeScreen();
          },
        ),

        // Protected Chat route
        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) {
            if (!authService.isAuthenticated.value) {
              debugPrint(
                  '[Router] /chat requested but not authenticated, going to /login');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/login');
              });
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            return const HomeScreen();
          },
        ),

        // Marketing & Other routes
        ...marketing_lazy.marketingRoutes,
        ...settings_lazy.settingsRoutes,
        ...admin_lazy.adminRoutes,

        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),

        GoRoute(
          path: '/callback',
          name: 'callback',
          builder: (context, state) {
            if (!kIsWeb) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/login');
              });
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final params = state.uri.queryParameters.isNotEmpty
                ? state.uri.queryParameters
                : Uri.base.queryParameters;
            return CallbackScreen(queryParams: params);
          },
        ),

        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
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
        if (isLoggingIn || isCallback) return null; // Allow these

        // ALLOW ACCESS TO HOME EVEN IF UNAUTHENTICATED
        if (state.matchedLocation == '/') return null;

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
