import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:zoidbot/bootstrap/bootstrapper.dart';
import 'package:zoidbot/config/app_config.dart';
import 'package:zoidbot/config/router.dart';
import 'package:zoidbot/config/theme.dart';

import 'package:zoidbot/di/locator.dart' as di;
import 'package:zoidbot/services/admin_center_service.dart';
import 'package:zoidbot/services/admin_data_flush_service.dart';
import 'package:zoidbot/services/admin_service.dart';
import 'package:zoidbot/services/app_initialization_service.dart';
import 'package:zoidbot/services/auth_service.dart';
import 'package:zoidbot/services/connection_manager_service.dart';
import 'package:zoidbot/services/desktop_client_detection_service.dart';
import 'package:zoidbot/services/enhanced_user_tier_service.dart';
import 'package:zoidbot/services/langchain_integration_service.dart';
import 'package:zoidbot/services/langchain_ollama_service.dart';
import 'package:zoidbot/services/langchain_prompt_service.dart';
import 'package:zoidbot/services/langchain_rag_service.dart';
import 'package:zoidbot/services/llm_audit_service.dart';
import 'package:zoidbot/services/llm_error_handler.dart';
import 'package:zoidbot/services/llm_provider_manager.dart';
import 'package:zoidbot/services/provider_configuration_manager.dart';
import 'package:zoidbot/services/provider_discovery_service.dart';
import 'package:zoidbot/services/streaming_chat_service.dart';
import 'package:zoidbot/services/streaming_proxy_service.dart';
import 'package:zoidbot/services/tunnel_service.dart';
import 'package:zoidbot/services/unified_connection_service.dart';
import 'package:zoidbot/services/user_container_service.dart';
import 'package:zoidbot/services/web_download_prompt_service.dart'
    if (dart.library.io) 'package:zoidbot/services/web_download_prompt_service_stub.dart';
import 'package:zoidbot/services/log_buffer_service.dart';
import 'package:zoidbot/services/theme_provider.dart';
import 'package:zoidbot/services/platform_detection_service.dart';
import 'package:zoidbot/services/platform_adapter.dart';
import 'package:zoidbot/providers/provider_builder.dart';
import 'web_plugins_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';
import 'package:zoidbot/widgets/tray_initializer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zoidbot/widgets/window_listener_widget.dart'
    if (dart.library.html) 'package:zoidbot/widgets/window_listener_widget_stub.dart';
import 'package:zoidbot/config/navigator_key.dart';
import 'package:zoidbot/utils/platform_file_utils.dart'
    if (dart.library.html) 'package:zoidbot/utils/platform_file_utils_web.dart';

void main(List<String> args) async {
  debugPrint('----- DART MAIN START ----- v10.1.187');

  if (args.isNotEmpty) {
    debugPrint('[Main] Command-line arguments received: $args');
    await _handleCommandLineArgs(args);
    return;
  }

  debugPrint('[Main] Initializing Sentry (FIRST after Flutter binding)...');

  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = AppConfig.sentryEnvironment;
        options.release = '${AppConfig.appName}@${AppConfig.appVersion}';
        options.tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
        options.debug = !kReleaseMode;
        options.enableLogs = true;
      },
      appRunner: () async {
        debugPrint('[Main] Sentry initialized, running app with Sentry...');
        _runAppWithSentry();
      },
    ).timeout(const Duration(seconds: 5));
    debugPrint('[Main] Sentry init completed');
  } catch (e) {
    debugPrint('Sentry initialization failed or timed out: $e');
    _runAppWithoutSentry();
  }
}

void _runAppWithSentry() {
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
  debugPrint('Running app without Sentry');
  _initializeClientLogBuffer();
  _runAppCommon();
}

void _runAppCommon() {
  Future<AppBootstrapData> loadApp() async {
    try {
      debugPrint('[Main] Bootstrapper loading...');
      final bootstrapper = AppBootstrapper();
      final result = await bootstrapper.load();
      debugPrint('[Main] Bootstrapper loaded');
      return result;
    } catch (e, stack) {
      debugPrint('Bootstrap failed: $e');
      try {
        await Sentry.captureException(e, stackTrace: stack);
      } catch (_) {}
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    }
  }

  final appLoadFuture = loadApp();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(
        SentryWidget(
          child: FutureProvider<AppBootstrapData?>(
            create: (_) => appLoadFuture,
            initialData: null,
            child: const ZoidbotApp(),
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
      } catch (_) {}
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

class ZoidbotApp extends StatefulWidget {
  const ZoidbotApp({super.key});

  @override
  State<ZoidbotApp> createState() => _ZoidbotAppState();
}

class _ZoidbotAppState extends State<ZoidbotApp> {
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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[App] build() called');
    final bootstrap = context.watch<AppBootstrapData?>();
    if (bootstrap == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: Scaffold(
          backgroundColor:
              Colors.grey[900],
          body: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ),
      );
    }

    _ensureAuthListener();

    try {
      final builder = AppProviderBuilder();
      return MultiProvider(
        providers: builder.buildProviders(),
        child: TrayInitializer(
          navigatorKey: navigatorKey,
          child: const _AppRouterHost(),
        ),
      );
    } catch (e, stack) {
      debugPrint('[App] Error building providers: $e');
      debugPrint('[App] Stack: $stack');
      Sentry.captureException(e, stackTrace: stack);
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
      return;
    }
    final authService = di.serviceLocator.get<AuthService>();
    authService.addListener(_onAuthStateChanged);
    _attachedAuthService = authService;
    _authListenerAttached = true;

    authService.areAuthenticatedServicesLoaded.addListener(() {
      if (authService.areAuthenticatedServicesLoaded.value && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    });
  }
}

Future<void> _handleCommandLineArgs(List<String> args) async {
  String? callbackUrl;
  for (final arg in args) {
    if (arg.startsWith('com.zoidbot.app://') ||
        arg.startsWith('zoidbot://')) {
      callbackUrl = arg;
      break;
    }
  }

  if (callbackUrl != null) {
    if (!kIsWeb) {
      try {
        await PlatformFileUtils.writeCallbackFile(callbackUrl);
      } catch (e) {
        debugPrint('[Main] Error writing callback file: $e');
      }
    }
  }
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
