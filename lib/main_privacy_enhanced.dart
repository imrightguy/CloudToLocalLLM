import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'auth/auth_provider_factory.dart';

import 'services/enhanced_user_tier_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/unified_connection_service.dart';
import 'services/tunnel_service.dart';
import 'services/connection_manager_service.dart';
import 'services/streaming_chat_service.dart';
import 'services/native_tray_service.dart';
import 'services/window_manager_service.dart';
import 'services/desktop_client_detection_service.dart';
import 'services/web_download_prompt_service.dart';
import 'services/user_container_service.dart';
import 'services/admin_service.dart';
import 'services/admin_data_flush_service.dart';
import 'services/conversation_storage_service.dart';
import 'services/privacy_storage_manager.dart';
import 'services/platform_service_manager.dart';
import 'di/locator.dart' as di;
import 'services/onboarding/setup_wizard_service.dart';
import 'widgets/window_listener_widget.dart';

// Global navigator key for navigation from system tray
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize platform detection early
  final platformManager = PlatformServiceManager();
  await platformManager.initialize();

  runApp(CloudToLocalLLMPrivacyApp(platformManager: platformManager));
}

/// Privacy-enhanced main application widget with comprehensive data protection
class CloudToLocalLLMPrivacyApp extends StatefulWidget {
  final PlatformServiceManager platformManager;

  const CloudToLocalLLMPrivacyApp({super.key, required this.platformManager});

  @override
  State<CloudToLocalLLMPrivacyApp> createState() =>
      _CloudToLocalLLMPrivacyAppState();
}

class _CloudToLocalLLMPrivacyAppState extends State<CloudToLocalLLMPrivacyApp> {
  bool _isInitialized = false;
  String _initializationStatus = 'Initializing privacy-first architecture...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _initializationStatus = 'Setting up privacy-first data storage...';
      });

      // Show the UI immediately to prevent black screen
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Initialize platform-specific services in background
      if (!kIsWeb) {
        await _initializeDesktopServices();
      }
    } catch (e) {
      debugPrint(' [App] Error during app initialization: $e');
      // Still show the UI even if initialization fails
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _initializationStatus = 'Initialization completed with warnings';
        });
      }
    }
  }

  Future<void> _initializeDesktopServices() async {
    try {
      debugPrint('[SystemTray] Initializing desktop services...');

      // Only initialize if platform supports it
      await widget.platformManager.initializeServiceSafely(
        'window_manager',
        () async {
          final windowManager = WindowManagerService();
          await windowManager.initialize();
        },
      );

      debugPrint('[SystemTray] Desktop services initialized');
    } catch (e, stackTrace) {
      debugPrint('[SystemTray] Failed to initialize desktop services: $e');
      debugPrint('[SystemTray] Stack trace: $stackTrace');
    }
  }

  void _navigateToRoute(String route) {
    try {
      debugPrint('[Navigation] Attempting to navigate to route: $route');

      BuildContext? context = navigatorKey.currentContext;
      context ??= navigatorKey.currentState?.context;

      if (context != null && context.mounted) {
        debugPrint(
          '[Navigation] Context available, executing navigation to: $route',
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (context!.mounted) {
              context.go(route);
              debugPrint(
                '[Navigation] Navigation command sent for route: $route',
              );
            }
          } catch (e) {
            debugPrint(
              ' [Navigation] Post-frame navigation error for $route: $e',
            );
          }
        });
      } else {
        debugPrint(
          '[Navigation] Cannot navigate to $route: no valid context available',
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          _retryNavigation(route, 1);
        });
      }
    } catch (e, stackTrace) {
      debugPrint(' [Navigation] Error navigating to $route: $e');
      debugPrint(' [Navigation] Stack trace: $stackTrace');
    }
  }

  void _retryNavigation(String route, int attempt) {
    if (attempt > 3) {
      debugPrint('[Navigation] Max retry attempts reached for route: $route');
      return;
    }

    debugPrint('[Navigation] Retry attempt $attempt for route: $route');

    final context =
        navigatorKey.currentContext ?? navigatorKey.currentState?.context;
    if (context != null && context.mounted) {
      try {
        context.go(route);
        debugPrint('[Navigation] Retry successful for route: $route');
      } catch (e) {
        debugPrint(' [Navigation] Retry failed for $route: $e');
        Future.delayed(const Duration(milliseconds: 1000), () {
          _retryNavigation(route, attempt + 1);
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _retryNavigation(route, attempt + 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Platform service manager (already initialized)
        ChangeNotifierProvider.value(value: widget.platformManager),

        // Authentication service with PostgreSQL session storage
        ChangeNotifierProvider(
          create: (_) {
            final authProvider = AuthProviderFactory.create();
            final authService = AuthService(authProvider);
            unawaited(
                authProvider.initialize()); // Initialize provider directly
            unawaited(authService.init());
            return authService;
          },
        ),

        // Enhanced user tier service with container management
        ChangeNotifierProvider(
          create: (_) => EnhancedUserTierService(),
        ),

        // Privacy-first conversation storage
        Provider(
          create: (_) {
            final storage = ConversationStorageService();
            // Initialize asynchronously
            storage.initialize().catchError((e) {
              debugPrint(' [ConversationStorage] Initialization error: $e');
            });
            return storage;
          },
        ),

        // Privacy storage manager
        ChangeNotifierProvider(
          create: (context) {
            final privacyManager = PrivacyStorageManager(
              conversationStorage: context.read<ConversationStorageService>(),
              userTierService: context.read<EnhancedUserTierService>(),
              authService: context.read<AuthService>(),
            );
            // Initialize asynchronously
            privacyManager.initialize().catchError((e) {
              debugPrint(' [PrivacyStorage] Initialization error: $e');
            });
            return privacyManager;
          },
        ),

        // Streaming proxy service
        ChangeNotifierProvider(
          create: (context) =>
              StreamingProxyService(authService: context.read<AuthService>()),
        ),

        // Desktop client detection service (web platform only)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            final clientDetection = DesktopClientDetectionService(
              authService: authService,
            );
            // Initialize only on web platform
            if (kIsWeb) {
              clientDetection.initialize();
            }
            return clientDetection;
          },
        ),

        // Web download prompt service (web platform only)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            final clientDetection =
                context.read<DesktopClientDetectionService>();
            final webDownloadPrompt = WebDownloadPromptService(
              authService: authService,
              clientDetectionService: clientDetection,
            );
            // Initialize only on web platform
            if (kIsWeb) {
              webDownloadPrompt.initialize();
            }
            return webDownloadPrompt;
          },
        ),

        // User container service
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            return UserContainerService(authService: authService);
          },
        ),

        // Tunnel service - use singleton from GetIt
        ChangeNotifierProvider(
          create: (context) => di.serviceLocator<TunnelService>(),
        ),

        // Connection manager service - use singleton from GetIt
        ChangeNotifierProvider(
          create: (context) {
            final connectionManager =
                di.serviceLocator<ConnectionManagerService>();
            connectionManager.initialize();
            return connectionManager;
          },
        ),

        // Streaming chat service - use singleton from GetIt
        ChangeNotifierProvider(
          create: (context) => di.serviceLocator<StreamingChatService>(),
        ),

        // Unified connection service - use singleton from GetIt
        ChangeNotifierProvider(
          create: (context) => di.serviceLocator<UnifiedConnectionService>(),
        ),

        // Admin services - use singletons from GetIt
        ChangeNotifierProvider(
          create: (context) => di.serviceLocator<AdminService>(),
        ),
        ChangeNotifierProvider(
          create: (context) => di.serviceLocator<AdminDataFlushService>(),
        ),

        // Setup wizard service - uses services from locator
        ChangeNotifierProvider(
          create: (context) => di.serviceLocator<SetupWizardService>(),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: _isInitialized
            ? _buildMainApp()
            : MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(_initializationStatus),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMainApp() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Initialize tray service after providers are available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeTrayService(context);
        });

        return WindowListenerWidget(
          child: MaterialApp.router(
            // App configuration
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,

            // Theme configuration
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light,

            // Router configuration
            routerConfig: AppRouter.createRouter(
              navigatorKey: navigatorKey,
              authService: authService,
            ),

            // Builder for additional configuration
            builder: (context, child) {
              return MediaQuery(
                // Ensure text scaling doesn't break the UI
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.of(
                      context,
                    ).textScaler.scale(1.0).clamp(0.8, 1.2),
                  ),
                ),
                child: child!,
              );
            },
          ),
        );
      },
    );
  }

  bool _trayInitialized = false;

  Future<void> _initializeTrayService(BuildContext context) async {
    if (_trayInitialized) return;
    _trayInitialized = true;

    try {
      debugPrint('[SystemTray] Initializing tray service...');

      final connectionManager = context.read<ConnectionManagerService>();
      final windowManager = context.read<WindowManagerService>();

      // Initialize native tray service
      final nativeTray = NativeTrayService();
      final success = await nativeTray.initialize(
        connectionManager: connectionManager,
        onShowWindow: () {
          debugPrint('[SystemTray] Native tray requested to show window');
          windowManager.showWindow();
        },
        onHideWindow: () {
          debugPrint(' [SystemTray] Native tray requested to hide window');
          windowManager.hideToTray();
        },
        onSettings: () {
          debugPrint('[SystemTray] Native tray requested to open settings');
          _navigateToRoute('/settings');
        },
        onQuit: () {
          debugPrint('[SystemTray] Native tray requested to quit application');
          windowManager.forceClose();
        },
      );

      if (success) {
        debugPrint('[SystemTray] Native tray service initialized successfully');
      } else {
        debugPrint(' [SystemTray] Failed to initialize native tray service');
      }
    } catch (e, stackTrace) {
      debugPrint('[SystemTray] Failed to initialize desktop services: $e');
      debugPrint('[SystemTray] Stack trace: $stackTrace');
    }
  }
}
