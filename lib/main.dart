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
import 'package:cloudtolocalllm/services/admin_center_service.dart';
import 'package:cloudtolocalllm/services/admin_data_flush_service.dart';
import 'package:cloudtolocalllm/services/admin_service.dart';
import 'package:cloudtolocalllm/services/app_initialization_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/desktop_client_detection_service.dart';
import 'package:cloudtolocalllm/services/enhanced_user_tier_service.dart';
import 'package:cloudtolocalllm/services/langchain_integration_service.dart';
import 'package:cloudtolocalllm/services/langchain_ollama_service.dart';
import 'package:cloudtolocalllm/services/langchain_prompt_service.dart';
import 'package:cloudtolocalllm/services/langchain_rag_service.dart';
import 'package:cloudtolocalllm/services/llm_audit_service.dart';
import 'package:cloudtolocalllm/services/llm_error_handler.dart';
import 'package:cloudtolocalllm/services/llm_provider_manager.dart';
import 'package:cloudtolocalllm/services/local_ollama_connection_service.dart';
import 'package:cloudtolocalllm/services/ollama_service.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/streaming_chat_service.dart';
import 'package:cloudtolocalllm/services/streaming_proxy_service.dart';
import 'package:cloudtolocalllm/services/tunnel_service.dart';
import 'package:cloudtolocalllm/services/unified_connection_service.dart';
import 'package:cloudtolocalllm/services/user_container_service.dart';
import 'package:cloudtolocalllm/services/web_download_prompt_service.dart'
    if (dart.library.io) 'package:cloudtolocalllm/services/web_download_prompt_service_stub.dart';
import 'package:cloudtolocalllm/services/log_buffer_service.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'web_plugins_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';
import 'package:cloudtolocalllm/widgets/tray_initializer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:cloudtolocalllm/widgets/window_listener_widget.dart'
    if (dart.library.html) 'package:cloudtolocalllm/widgets/window_listener_widget_stub.dart';
import 'package:cloudtolocalllm/config/navigator_key.dart';
import 'package:cloudtolocalllm/utils/platform_file_utils.dart'
    if (dart.library.html) 'package:cloudtolocalllm/utils/platform_file_utils_web.dart';

// navigatorKey is now imported from config/navigator_key.dart

void main(List<String> args) async {
  // Immediate logging to verify Dart entry point is reached
  // Build trigger: force new release tag
  print('----- DART MAIN START ----- v10.1.187');

  // Handle command-line arguments (OAuth callback URLs)
  if (args.isNotEmpty) {
    print('[Main] Command-line arguments received: $args');
    await _handleCommandLineArgs(args);
    return; // Exit after handling callback
  }

  // Flutter requires WidgetsFlutterBinding to be initialized first
  // Moved inside runZonedGuarded in _runAppCommon to avoid Zone mismatch
  // WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry IMMEDIATELY after Flutter binding (before all other services)
  print('[Main] Initializing Sentry (FIRST after Flutter binding)...');

  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = AppConfig.sentryEnvironment;
        options.release = '${AppConfig.appName}@${AppConfig.appVersion}';
        // Lower sample rate in production to reduce costs
        options.tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
        // Enable debug only in development
        options.debug = !kReleaseMode;
        // Enable Sentry Logs
        options.enableLogs = true;
      },
      appRunner: () async {
        print('[Main] Sentry initialized, running app with Sentry...');
        _runAppWithSentry();
      },
    ).timeout(const Duration(seconds: 5));
    print('[Main] Sentry init completed');
  } catch (e) {
    print('Sentry initialization failed or timed out: $e');
    _runAppWithoutSentry();
  }
}

void _runAppWithSentry() {
  // Now that Sentry is initialized, set up error handlers
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: \'${details.exception}\'');
    if (details.stack != null) {
      debugPrint('Stack trace: ${details.stack}');
    }
    Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
    );
  };

  _initializeClientLogBuffer();
  _runAppCommon();
}

void _runAppWithoutSentry() {
  print('Running app without Sentry');
  _initializeClientLogBuffer();
  _runAppCommon();
}

void _runAppCommon() {
  Future<AppBootstrapData> loadApp() async {
    // Run the main bootstrap process
    try {
      print('[Main] Bootstrapper loading...');
      final bootstrapper = AppBootstrapper();
      final result = await bootstrapper.load();
      print('[Main] Bootstrapper loaded');
      return result;
    } catch (e, stack) {
      debugPrint('Bootstrap failed: $e');
      try {
        Sentry.captureException(e, stackTrace: stack);
      } catch (_) {} // Ignore Sentry errors here
      // Return minimal bootstrap data to allow app to load error screen or retry
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    }
  }

  final appLoadFuture = loadApp();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Run the app inside a zone to catch async errors
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(
        SentryWidget(
          child: FutureProvider<AppBootstrapData?>(
            create: (_) => appLoadFuture,
            initialData: null,
            child: const CloudToLocalLLMApp(),
          ),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
      debugPrint('Stack trace: $stack');
      try {
        Sentry.captureException(
          error,
          stackTrace: stack,
        );
      } catch (_) {} // Ignore Sentry errors here
    },
  );
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
  const CloudToLocalLLMApp({super.key});

  @override
  State<CloudToLocalLLMApp> createState() => _CloudToLocalLLMAppState();
}

class _CloudToLocalLLMAppState extends State<CloudToLocalLLMApp> {
  bool _authListenerAttached = false;
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
    print('[App] build() called');
    final bootstrap = context.watch<AppBootstrapData?>();
    print('[App] bootstrap: $bootstrap');
    if (bootstrap == null) {
      print('[App] Bootstrap is null, showing loading screen');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: Scaffold(
          backgroundColor:
              Colors.grey[900], // Dark background for loading screen
          body: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ),
      );
    }

    print('[App] Bootstrap loaded, building app');
    _ensureAuthListener();

    // Build providers list - authenticated services will be added when registered
    // This rebuilds when auth state changes
    try {
      return MultiProvider(
        providers: _buildProviders(),
        child: TrayInitializer(
          navigatorKey: navigatorKey,
          child: const _AppRouterHost(),
        ),
      );
    } catch (e, stack) {
      print('[App] Error building providers: $e');
      print('[App] Stack: $stack');
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
      print(
          '[App] AuthService not registered yet - deferring listener attachment');
      return;
    }
    final authService = di.serviceLocator.get<AuthService>();
    authService.addListener(_onAuthStateChanged);
    _attachedAuthService = authService;
    _authListenerAttached = true;

    // Listen for authenticated services to load and trigger rebuild
    authService.areAuthenticatedServicesLoaded.addListener(() {
      if (authService.areAuthenticatedServicesLoaded.value && mounted) {
        print(
            '[App] Authenticated services became loaded, triggering rebuild...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              print('[App] Provider tree rebuilt with authenticated services');
            });
          }
        });
      }
    });

    // If authenticated services are already loaded, trigger a rebuild now
    if (authService.areAuthenticatedServicesLoaded.value) {
      print(
          '[App] Authenticated services already loaded, triggering rebuild...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            print('[App] Provider tree rebuilt with authenticated services');
          });
        }
      });
    }
  }

  List<SingleChildWidget> _buildProviders() {
    final providers = <SingleChildWidget>[];

    // Core services
    _addCoreProvider<AuthService>(providers);
    _addCoreProvider<LocalOllamaConnectionService>(providers);
    _addCoreProvider<DesktopClientDetectionService>(providers);
    _addCoreProvider<AppInitializationService>(providers);
    _addCoreProvider<WebDownloadPromptService>(providers);
    _addCoreProvider<ProviderDiscoveryService>(providers);
    _addCoreProvider<LLMErrorHandler>(providers);
    _addCoreProvider<LangChainPromptService>(providers);
    _addCoreProvider<EnhancedUserTierService>(providers);
    _addCoreProvider<ThemeProvider>(providers);
    _addCoreProvider<ProviderConfigurationManager>(providers);
    _addCoreProvider<PlatformDetectionService>(providers);

    try {
      if (di.serviceLocator.isRegistered<PlatformAdapter>()) {
        final platformAdapter = di.serviceLocator.get<PlatformAdapter>();
        providers.add(
          Provider<PlatformAdapter>.value(value: platformAdapter),
        );
      }
    } catch (e, stack) {
      print('[Providers] Error adding PlatformAdapter: $e');
      Sentry.captureException(e, stackTrace: stack);
    }

    // Authenticated services
    _addProviderIfRegistered<TunnelService>(providers);
    _addProviderIfRegistered<StreamingProxyService>(providers);
    _addProviderIfRegistered<OllamaService>(providers);
    _addProviderIfRegistered<UserContainerService>(providers);
    _addProviderIfRegistered<LangChainIntegrationService>(providers);
    _addProviderIfRegistered<LLMProviderManager>(providers);
    _addProviderIfRegistered<ConnectionManagerService>(providers);
    _addProviderIfRegistered<LangChainOllamaService>(providers);
    _addProviderIfRegistered<LangChainRAGService>(providers);
    _addProviderIfRegistered<LLMAuditService>(providers);
    _addProviderIfRegistered<StreamingChatService>(providers);
    _addProviderIfRegistered<UnifiedConnectionService>(providers);
    _addProviderIfRegistered<AdminService>(providers);
    _addProviderIfRegistered<AdminDataFlushService>(providers);
    _addProviderIfRegistered<AdminCenterService>(providers);

    return providers;
  }

  void _addCoreProvider<T extends ChangeNotifier>(
      List<SingleChildWidget> providers) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(ChangeNotifierProvider<T>.value(value: service));
      }
    } catch (e, stack) {
      print('[Providers] Error adding core provider $T: $e');
      Sentry.captureException(e, stackTrace: stack);
    }
  }

  void _addProviderIfRegistered<T extends ChangeNotifier>(
      List<SingleChildWidget> providers) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(ChangeNotifierProvider<T>.value(value: service));
      }
    } catch (e) {
      print('[Providers] Error adding provider $T: $e');
    }
  }
}

Future<void> _handleCommandLineArgs(List<String> args) async {
  print('[Main] Handling command-line arguments: $args');
  String? callbackUrl;
  for (final arg in args) {
    if (arg.startsWith('com.cloudtolocalllm.app://') ||
        arg.startsWith('cloudtolocalllm://')) {
      callbackUrl = arg;
      break;
    }
  }

  if (callbackUrl != null) {
    print('[Main] Found OAuth callback URL: $callbackUrl');
    if (!kIsWeb) {
      try {
        await PlatformFileUtils.writeCallbackFile(callbackUrl);
        print('[Main] Wrote callback URL to temp file');
      } catch (e) {
        print('[Main] Error writing callback file: $e');
      }
    }
  }
  print('[Main] Command-line handler exiting');
}

class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost();

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  GoRouter? _router;
  bool _initialized = false;

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
    final authService = context.read<AuthService>();
    if (authService.isSessionBootstrapComplete) {
      _initializeRouter(authService);
    } else {
      await authService.sessionBootstrapFuture;
      if (!mounted) return;
      _initializeRouter(authService);
    }
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
    } catch (_) {}

    return WindowListenerWidget(
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider?.themeMode ?? ThemeMode.system,
        routerConfig: router,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(
                mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.2),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
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
