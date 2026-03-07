import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:cloudtolocalllm/bootstrap/bootstrapper.dart';
import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:cloudtolocalllm/config/router.dart';
import 'package:cloudtolocalllm/config/theme.dart';

import 'package:cloudtolocalllm/di/locator.dart' as di;
import 'package:cloudtolocalllm/services/app_initialization_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/desktop_client_detection_service.dart';
import 'package:cloudtolocalllm/services/enhanced_user_tier_service.dart';
import 'package:cloudtolocalllm/services/langchain_prompt_service.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/streaming_chat_service.dart';
import 'package:cloudtolocalllm/services/web_download_prompt_service.dart'
    if (dart.library.io) 'package:cloudtolocalllm/services/web_download_prompt_service_stub.dart';
import 'package:cloudtolocalllm/services/log_buffer_service.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/google_workspace_service.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/agent_lifecycle_service.dart';
import 'package:cloudtolocalllm/services/agent_status_service.dart';
import 'package:cloudtolocalllm/services/rate_limit_manager.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/services/setup_status_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';
import 'package:cloudtolocalllm/screens/marketing/homepage_screen.dart';
import 'web_plugins_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';
import 'package:cloudtolocalllm/widgets/tray_initializer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:cloudtolocalllm/widgets/window_listener_widget.dart'
    if (dart.library.html) 'package:cloudtolocalllm/widgets/window_listener_widget_stub.dart';
import 'package:cloudtolocalllm/config/navigator_key.dart';
import 'package:cloudtolocalllm/utils/platform_file_utils.dart'
    if (dart.library.html) 'package:cloudtolocalllm/utils/platform_file_utils_web.dart';
import 'package:cloudtolocalllm/utils/web_interop_stub.dart'
    if (dart.library.html) 'package:cloudtolocalllm/utils/web_interop.dart';

// navigatorKey is now imported from config/navigator_key.dart

void main(List<String> args) async {
  // Flutter requires WidgetsFlutterBinding to be initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Immediate logging to verify Dart entry point is reached
  // Build trigger: force new release tag
  debugPrint('----- DART MAIN START ----- v10.1.187');

  // Handle command-line arguments (OAuth callback URLs)
  if (args.isNotEmpty) {
    debugPrint('[Main] Command-line arguments received: $args');
    await _handleCommandLineArgs(args);
    return; // Exit after handling callback
  }

  // Flutter requires WidgetsFlutterBinding to be initialized first
  // Moved inside runZonedGuarded in _runAppCommon to avoid Zone mismatch
  // WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry IMMEDIATELY after Flutter binding (before all other services)
  debugPrint('[Main] Initializing Sentry (FIRST after Flutter binding)...');

  // TEMPORARY: Skip Sentry to test app loading
  debugPrint('[Main] Skipping Sentry for testing');
  _runAppWithoutSentry();
}

void _runAppWithoutSentry() {
  debugPrint('Running app without Sentry');
  if (!_isMarketingLandingPath()) {
    _initializeClientLogBuffer();
  }
  _runAppCommon();
}

void _runAppCommon() {
  if (_isMarketingLandingPath()) {
    debugPrint('[Main] Serving marketing landing shell without app bootstrap');
    runApp(const _MarketingShellApp());
    return;
  }

  Future<AppBootstrapData> loadApp() async {
    // Run the main bootstrap process
    try {
      debugPrint('[Main] Bootstrapper loading...');
      final bootstrapper = AppBootstrapper();
      final result = await bootstrapper.load().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint(
              '[Main] Bootstrap timed out after 30s, continuing with degraded startup');
          return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
        },
      );
      debugPrint('[Main] Bootstrapper loaded');
      return result;
    } catch (e, stack) {
      debugPrint('Bootstrap failed: $e');
      try {
        await Sentry.captureException(e, stackTrace: stack);
      } catch (sentryError) {
        debugPrint('[Main] ⚠ Sentry capture failed: $sentryError');
        // Continue without Sentry - don't let error reporting failure crash the app
      }
      // Return minimal bootstrap data to allow app to load error screen or retry
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    }
  }

  final appLoadFuture = loadApp();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  debugPrint('[Main] Starting runApp...');
  runApp(
    SentryWidget(
      child: CloudToLocalLLMApp(bootstrapFuture: appLoadFuture),
    ),
  );
  debugPrint('[Main] runApp completed');
}

bool _isMarketingLandingPath() {
  if (!kIsWeb) {
    return false;
  }

  try {
    final path = window.location.pathname;
    return path == '/' || path == '/index.html';
  } catch (_) {
    return false;
  }
}

class _MarketingShellApp extends StatelessWidget {
  const _MarketingShellApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomepageScreen(),
    );
  }
}

void _initializeClientLogBuffer() {
  if (!kIsWeb) {
    return;
  }

  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      LogBufferService.instance.add(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };
}

/// Main application widget with comprehensive loading screen
class CloudToLocalLLMApp extends StatefulWidget {
  final Future<AppBootstrapData> bootstrapFuture;

  const CloudToLocalLLMApp({super.key, required this.bootstrapFuture});

  @override
  State<CloudToLocalLLMApp> createState() => _CloudToLocalLLMAppState();
}

class _CloudToLocalLLMAppState extends State<CloudToLocalLLMApp> {
  bool _authListenerAttached = false;
  bool _authRetryScheduled = false;
  AuthService? _attachedAuthService;

  @override
  void dispose() {
    if (_authListenerAttached && _attachedAuthService != null) {
      _attachedAuthService!.removeListener(_onAuthStateChanged);
    }
    super.dispose();
  }

  void _onAuthStateChanged() {
    // Rebuild when auth state changes so authenticated services can be provided
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[App] build() called with FutureBuilder');

    return FutureBuilder<AppBootstrapData>(
      future: widget.bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          debugPrint('[App] Bootstrap loading, showing loading screen');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: Scaffold(
              backgroundColor: Colors.grey[900],
              body: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('[App] Bootstrap error: ${snapshot.error}');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Initialization Error'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}'),
                  ],
                ),
              ),
            ),
          );
        }

        final bootstrap = snapshot.data!;
        debugPrint('[App] Bootstrap loaded, building app');
        return _buildAppWithBootstrap(bootstrap);
      },
    );
  }

  Widget _buildAppWithBootstrap(AppBootstrapData bootstrap) {
    _ensureAuthListener();

    // Build providers list - authenticated services will be added when registered
    // This rebuilds when auth state changes
    try {
      debugPrint('[App] Creating TrayInitializer...');
      final trayInitializer = TrayInitializer(
        navigatorKey: navigatorKey,
        child: const _AppRouterHost(),
      );
      debugPrint('[App] TrayInitializer created');

      debugPrint('[App] Building MultiProvider...');

      // Add providers one by one with debug
      final providersList = <SingleChildWidget>[];

      debugPrint('[App] Adding AuthService...');
      if (di.serviceLocator.isRegistered<AuthService>()) {
        providersList.add(ListenableProvider<AuthService>.value(
          value: di.serviceLocator.get<AuthService>(),
        ));
        debugPrint('[App] AuthService added');
      } else {
        debugPrint('[App] AuthService NOT registered!');
      }

      // Add other core services needed by HomeScreen
      _addProviderIfAvailable<StreamingChatService>(
          providersList, 'StreamingChatService');
      _addProviderIfAvailable<AppInitializationService>(
          providersList, 'AppInitializationService');
      _addProviderIfAvailable<ThemeProvider>(providersList, 'ThemeProvider');
      _addProviderIfAvailableNoChangeNotifier<ProviderDiscoveryService>(
          providersList, 'ProviderDiscoveryService');
      _addProviderIfAvailableNoChangeNotifier<ProviderConfigurationManager>(
          providersList, 'ProviderConfigurationManager');
      _addProviderIfAvailable<DesktopClientDetectionService>(
          providersList, 'DesktopClientDetectionService');
      _addProviderIfAvailable<WebDownloadPromptService>(
          providersList, 'WebDownloadPromptService');
      _addProviderIfAvailable<EnhancedUserTierService>(
          providersList, 'EnhancedUserTierService');
      _addProviderIfAvailableNoChangeNotifier<LangChainPromptService>(
          providersList, 'LangChainPromptService');
      _addProviderIfAvailable<PlatformDetectionService>(
          providersList, 'PlatformDetectionService');

      // Add agent-related services
      _addProviderIfAvailable<AgentLifecycleService>(
          providersList, 'AgentLifecycleService');
      _addProviderIfAvailable<GatewayControlService>(
          providersList, 'GatewayControlService');
      _addProviderIfAvailableNoChangeNotifier<AgentStatusService>(
          providersList, 'AgentStatusService');
      _addProviderIfAvailable<ConnectionManagerService>(
          providersList, 'ConnectionManagerService');
      _addProviderIfAvailableNoChangeNotifier<RateLimitManager>(
          providersList, 'RateLimitManager');

      // Add setup wizard services
      _addProviderIfAvailable<SetupWizardService>(
          providersList, 'SetupWizardService');
      _addProviderIfAvailable<SetupStatusService>(
          providersList, 'SetupStatusService');

      // Add Google Workspace Service
      _addProviderIfAvailable<GoogleWorkspaceService>(
          providersList, 'GoogleWorkspaceService');

      debugPrint(
          '[App] Returning MultiProvider with ${providersList.length} providers');
      return MultiProvider(
        providers: providersList,
        child: trayInitializer,
      );
    } catch (e, stack) {
      debugPrint('[App] Error building providers: $e');
      debugPrint('[App] Stack: $stack');
      Sentry.captureException(e, stackTrace: stack);
      // Return error screen instead of crashing
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Initialization Error'),
                const SizedBox(height: 8),
                Text(e.toString()),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _ensureAuthListener() {
    if (_authListenerAttached) {
      return;
    }
    if (!di.serviceLocator.isRegistered<AuthService>()) {
      debugPrint(
          '[App] AuthService not registered yet - deferring listener attachment');
      if (!_authRetryScheduled) {
        _authRetryScheduled = true;
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!mounted) {
            return;
          }
          _authRetryScheduled = false;
          setState(() {
            debugPrint('[App] Retrying provider tree build for AuthService');
          });
        });
      }
      return;
    }
    final authService = di.serviceLocator.get<AuthService>();
    authService.addListener(_onAuthStateChanged);
    _attachedAuthService = authService;
    _authListenerAttached = true;

    // Listen for authenticated services to load and trigger rebuild
    authService.areAuthenticatedServicesLoaded.addListener(() {
      if (authService.areAuthenticatedServicesLoaded.value && mounted) {
        debugPrint(
            '[App] Authenticated services became loaded, triggering rebuild...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              debugPrint(
                  '[App] Provider tree rebuilt with authenticated services');
            });
          }
        });
      }
    });

    // If authenticated services are already loaded, trigger a rebuild now
    if (authService.areAuthenticatedServicesLoaded.value) {
      debugPrint(
          '[App] Authenticated services already loaded, triggering rebuild...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            debugPrint(
                '[App] Provider tree rebuilt with authenticated services');
          });
        }
      });
    }
  }

  void _addProviderIfAvailable<T extends ChangeNotifier>(
      List<SingleChildWidget> providers, String name) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(ChangeNotifierProvider<T>.value(value: service));
        debugPrint('[App] $name added');
      } else {
        debugPrint('[App] $name not registered, skipping');
      }
    } catch (e) {
      debugPrint('[App] Error adding $name: $e');
    }
  }

  void _addProviderIfAvailableNoChangeNotifier<T extends Object>(
      List<SingleChildWidget> providers, String name) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        // Use InheritedProvider to avoid type checking warnings
        providers.add(InheritedProvider<T>.value(value: service));
        debugPrint('[App] $name added');
      } else {
        debugPrint('[App] $name not registered, skipping');
      }
    } catch (e) {
      debugPrint('[App] Error adding $name: $e');
    }
  }
}

Future<void> _handleCommandLineArgs(List<String> args) async {
  debugPrint('[Main] Handling command-line arguments: $args');
  String? callbackUrl;
  for (final arg in args) {
    if (arg.startsWith('com.cloudtolocalllm.app://') ||
        arg.startsWith('cloudtolocalllm://')) {
      callbackUrl = arg;
      break;
    }
  }

  if (callbackUrl != null) {
    debugPrint('[Main] Found OAuth callback URL: $callbackUrl');
    if (!kIsWeb) {
      try {
        await PlatformFileUtils.writeCallbackFile(callbackUrl);
        debugPrint('[Main] Wrote callback URL to temp file');
      } catch (e) {
        debugPrint('[Main] Error writing callback file: $e');
      }
    }
  }
  debugPrint('[Main] Command-line handler exiting');
}

class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost();

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  GoRouter? _router;
  bool _initialized = false;
  bool _retryPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;
      _initialized = true;
      _initializeRouterWhenReady();
    });
  }

  void _initializeRouterWhenReady() async {
    AuthService? authService;
    try {
      authService = context.read<AuthService>();
    } catch (e) {
      debugPrint('[Router] AuthService not in provider tree yet: $e');
      if (di.serviceLocator.isRegistered<AuthService>()) {
        authService = di.serviceLocator.get<AuthService>();
      }
    }

    if (authService == null) {
      if (!_retryPending) {
        _retryPending = true;
        Future<void>.delayed(const Duration(seconds: 2), () {
          _retryPending = false;
          if (!mounted || _router != null) {
            return;
          }
          _initializeRouterWhenReady();
        });
      }
      return;
    }

    // Skip waiting for bootstrap - initialize router immediately
    debugPrint('[Router] Initializing without waiting for bootstrap');

    if (!mounted) return;
    _initializeRouter(authService);
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: Scaffold(
          backgroundColor: Colors.grey[900],
          body: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ),
      );
    }

    ThemeProvider? themeProvider;
    try {
      themeProvider = context.watch<ThemeProvider>();
    } catch (e) {
      debugPrint('[Main] ⚠ ThemeProvider not available: $e');
      // themeProvider remains null, will use ThemeMode.system as fallback
    }

    return WindowListenerWidget(
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider?.themeMode ?? ThemeMode.system,
        routerConfig: router,
        builder: (context, child) {
          // Error fallback
          if (child == null) {
            return const Scaffold(
              body: Center(
                child: Text('Loading...', style: TextStyle(fontSize: 18)),
              ),
            );
          }

          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(
                mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.2),
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _initializeRouter(AuthService authService) {
    setState(() {
      _router = AppRouter.createRouter(
        navigatorKey: navigatorKey,
        authService: authService,
      );
    });
  }
}
// Deployment trigger 1770824833
