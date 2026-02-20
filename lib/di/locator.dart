import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:cloudtolocalllm/services/admin_data_flush_service.dart';
import 'package:cloudtolocalllm/services/admin_service.dart';
import 'package:cloudtolocalllm/services/app_initialization_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/session_storage_service.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/auth/auth_provider.dart';
import 'package:cloudtolocalllm/auth/providers/auth0_auth_provider.dart';
import 'package:cloudtolocalllm/services/desktop_client_detection_service.dart';
import 'package:cloudtolocalllm/services/enhanced_user_tier_service.dart';
import 'package:cloudtolocalllm/services/langchain_integration_service.dart';
import 'package:cloudtolocalllm/services/langchain_prompt_service.dart';
import 'package:cloudtolocalllm/services/langchain_rag_service.dart'
    if (dart.library.html) 'package:cloudtolocalllm/services/langchain_rag_service_stub.dart';
import 'package:cloudtolocalllm/services/llm_audit_service.dart';
import 'package:cloudtolocalllm/services/llm_error_handler.dart';
import 'package:cloudtolocalllm/services/llm_provider_manager.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/streaming_chat_service.dart';
import 'package:cloudtolocalllm/services/streaming_proxy_service.dart';
import 'package:cloudtolocalllm/services/tunnel_service.dart';
import 'package:cloudtolocalllm/services/tunnel/tunnel_config_manager.dart';
import 'package:cloudtolocalllm/services/unified_connection_service.dart';
import 'package:cloudtolocalllm/services/user_container_service.dart';
import 'package:cloudtolocalllm/services/web_download_prompt_service.dart'
    if (dart.library.io) 'package:cloudtolocalllm/services/web_download_prompt_service_stub.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';
import 'package:cloudtolocalllm/services/settings_import_export_service.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/services/admin_center_service.dart';
import 'package:cloudtolocalllm/services/google_workspace_service.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';
import 'package:cloudtolocalllm/services/url_scheme_registration_service.dart';
import 'package:cloudtolocalllm/services/token_storage_service.dart';
import 'package:cloudtolocalllm/database/local_brain.dart';
import 'package:cloudtolocalllm/services/brain_sync_service.dart';
import 'package:cloudtolocalllm/services/full_context_indexer.dart';
import 'package:cloudtolocalllm/services/rate_limit_manager.dart';
import 'package:cloudtolocalllm/services/router_server.dart';
import 'package:cloudtolocalllm/services/providers/zhipu_adapter.dart';
import 'package:cloudtolocalllm/services/providers/google_adapter.dart';
import 'package:cloudtolocalllm/services/providers/moonshot_adapter.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';
import 'package:cloudtolocalllm/services/agent_status_service.dart';
import 'package:cloudtolocalllm/services/agent_lifecycle_service.dart';
import 'package:cloudtolocalllm/services/setup_status_service.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/services/openclaw_manager/gateway_control_service.dart';

final GetIt serviceLocator = GetIt.instance;

bool _coreServicesRegistered = false;
bool _authenticatedServicesRegistered = false;
bool _isRegisteringAuthenticatedServices = false;

/// Registers core services that are needed before authentication.
/// These services don't require authentication tokens and can be safely
/// initialized during app bootstrap.
Future<void> setupCoreServices() async {
  if (_coreServicesRegistered) {
    debugPrint('[ServiceLocator] Core services already registered, skipping');
    return;
  }

  debugPrint('[ServiceLocator] ===== REGISTERING CORE SERVICES START =====');
  debugPrint('[ServiceLocator] Registering core services...');

  // Settings preference service - manages user preferences
  // Register this early as other services (like AuthProvider) may need it
  final settingsPreferenceService = SettingsPreferenceService();
  serviceLocator.registerSingleton<SettingsPreferenceService>(
    settingsPreferenceService,
  );

  // Session storage service for PostgreSQL session management
  final sessionStorageService = SessionStorageService();
  serviceLocator
      .registerSingleton<SessionStorageService>(sessionStorageService);

  // Token storage service for encrypted local persistence (SQLite)
  final tokenStorageService = TokenStorageService();
  await tokenStorageService.init();
  serviceLocator.registerSingleton<TokenStorageService>(tokenStorageService);

  // Local Brain Database - Main relational engine for durable memory
  final localBrain = LocalBrain();
  serviceLocator.registerSingleton<LocalBrain>(localBrain);

  // Brain Sync Service - Synchronizes local thoughts with cloud backbone
  final brainSyncService = BrainSyncService(localBrain);
  serviceLocator.registerSingleton<BrainSyncService>(brainSyncService);
  brainSyncService.startSync();

  // Full Context Indexer - Manages system-wide file indexing in local brain
  final fullContextIndexer = FullContextIndexer(localBrain);
  serviceLocator.registerSingleton<FullContextIndexer>(fullContextIndexer);

  // LLM Router Services
  final rateLimitManager = RateLimitManager(localBrain);
  serviceLocator.registerSingleton<RateLimitManager>(rateLimitManager);

  final routerServer = RouterServer(
    rateLimitManager: rateLimitManager,
    providers: {
      'zhipu':
          ZhipuAdapter(apiKey: const String.fromEnvironment('GLM_API_KEY')),
      'google':
          GoogleAdapter(apiKey: const String.fromEnvironment('GEMINI_API_KEY')),
      'moonshot':
          MoonshotAdapter(apiKey: const String.fromEnvironment('KIMI_API_KEY')),
    },
  );
  serviceLocator.registerSingleton<RouterServer>(routerServer);

  // Start the router server in the background
  unawaited(routerServer.start());

  // Authentication Provider - Using platform-specific provider
  late AuthProvider authProvider;

  try {
    debugPrint('[Locator] Detecting platform...');

    // Check if we're on web first
    if (kIsWeb) {
      debugPrint('[Locator] ✓ Web platform detected, using Auth0AuthProvider');
      authProvider = Auth0AuthProvider();
    } else {
      // Use Auth0AuthProvider for all desktop platforms
      debugPrint('[Locator] Using Auth0AuthProvider for desktop');
      authProvider = Auth0AuthProvider();
    }
  } catch (e, stack) {
    debugPrint('[Locator] ERROR during platform detection: $e');
    debugPrint('[Locator] Stack trace: $stack');
    // Fallback to Auth0 if platform detection fails
    debugPrint('[Locator] Falling back to Auth0AuthProvider');
    authProvider = Auth0AuthProvider();
  }

  debugPrint('[Locator] Selected auth provider: ${authProvider.runtimeType}');

  // Register strictly as AuthProvider interface to enforce abstraction
  try {
    debugPrint('[Locator] Registering AuthProvider...');
    serviceLocator.registerSingleton<AuthProvider>(authProvider);
    debugPrint('[Locator] ✓ AuthProvider registered successfully');
  } catch (e, stack) {
    debugPrint('[Locator] ❌ CRITICAL ERROR registering AuthProvider: $e');
    debugPrint('[Locator] Stack trace: $stack');
    rethrow;
  }

  late final AuthService authService;
  try {
    debugPrint('[Locator] Registering AuthService...');
    authService = AuthService(authProvider);
    serviceLocator.registerSingleton<AuthService>(authService);
    debugPrint('[Locator] ✓ AuthService registered successfully');
  } catch (e, stack) {
    debugPrint('[Locator] ❌ CRITICAL ERROR registering AuthService: $e');
    debugPrint('[Locator] Stack trace: $stack');
    rethrow;
  }

  // Provider discovery - create but don't initialize until auth
  final providerDiscoveryService = ProviderDiscoveryService();
  serviceLocator.registerSingleton<ProviderDiscoveryService>(
    providerDiscoveryService,
  );

  // LLM Error Handler - lightweight, doesn't require auth
  final llmErrorHandler = LLMErrorHandler(
    providerDiscovery: providerDiscoveryService,
  );
  serviceLocator.registerSingleton<LLMErrorHandler>(llmErrorHandler);

  // LangChain Prompt Service - create but don't initialize templates until auth
  final langchainPromptService = LangChainPromptService();
  serviceLocator.registerSingleton<LangChainPromptService>(
    langchainPromptService,
  );

  // Desktop client detection - can check client type without auth
  final desktopClientDetectionService = DesktopClientDetectionService(
    authService: authService,
  );
  serviceLocator.registerSingleton<DesktopClientDetectionService>(
    desktopClientDetectionService,
  );

  // App initialization service - manages initialization order
  final appInitializationService = AppInitializationService(
    authService: authService,
  );
  serviceLocator.registerSingleton<AppInitializationService>(
    appInitializationService,
  );

  // Settings import/export service - handles settings backup/restore
  final settingsImportExportService = SettingsImportExportService(
    preferencesService: settingsPreferenceService,
  );
  serviceLocator.registerSingleton<SettingsImportExportService>(
    settingsImportExportService,
  );

  // Platform detection service - detects current platform and provides platform info
  final platformDetectionService = PlatformDetectionService();
  serviceLocator.registerSingleton<PlatformDetectionService>(
    platformDetectionService,
  );
  debugPrint('[ServiceLocator] ✓ PlatformDetectionService registered');

  // Platform adapter - provides platform-appropriate UI components
  final platformAdapter = PlatformAdapter(platformDetectionService);
  serviceLocator.registerSingleton<PlatformAdapter>(platformAdapter);

  // Theme provider - manages application theme mode
  final themeProvider = ThemeProvider();
  serviceLocator.registerSingleton<ThemeProvider>(themeProvider);

  // Provider configuration manager - manages local LLM provider configurations
  final providerConfigurationManager = ProviderConfigurationManager();
  serviceLocator.registerSingleton<ProviderConfigurationManager>(
    providerConfigurationManager,
  );

  // URL scheme registration service - registers custom URL schemes for OAuth callbacks (Windows)
  serviceLocator.registerSingleton<UrlSchemeRegistrationService>(
    UrlSchemeRegistrationService(),
  );

  // Gateway control service - manages OpenClaw Gateway lifecycle (start/stop/restart)
  final gatewayControlService =
      GatewayControlService(settingsPreferenceService);
  serviceLocator
      .registerSingleton<GatewayControlService>(gatewayControlService);

  // Setup status service - tracks first-run and setup completion
  final setupStatusService = SetupStatusService(
    authService: authService,
    clientDetectionService: desktopClientDetectionService,
  );
  serviceLocator.registerSingleton<SetupStatusService>(setupStatusService);

  // Setup wizard service - manages the onboarding wizard flow
  final setupWizardService = SetupWizardService(
    serviceLocator.get<ProviderDiscoveryService>(),
    setupStatusService,
    providerConfigurationManager,
  );
  serviceLocator.registerSingleton<SetupWizardService>(setupWizardService);

  // Web download prompt service - can be created but won't do heavy work until auth
  final webDownloadPromptService = WebDownloadPromptService(
    authService: authService,
    clientDetectionService: desktopClientDetectionService,
  );
  // Don't initialize yet - wait for auth
  serviceLocator.registerSingleton<WebDownloadPromptService>(
    webDownloadPromptService,
  );

  // Enhanced user tier service - can be created but won't initialize until auth
  final enhancedUserTierService = EnhancedUserTierService();
  serviceLocator.registerSingleton<EnhancedUserTierService>(
    enhancedUserTierService,
  );

  // Don't initialize yet - wait for auth token

  debugPrint('[ServiceLocator] Core services registered successfully');

  // Initialize AuthService last, after all dependencies are registered
  try {
    debugPrint('[Locator] Initializing AuthService...');
    final authService = serviceLocator.get<AuthService>();
    await authService.init();
    debugPrint('[Locator] ✓ AuthService initialized successfully');

    // On Desktop, auto-bootstrap authenticated services immediately
    // This allows local use without mandatory login
    if (!kIsWeb) {
      debugPrint(
          '[Locator] Desktop detected, auto-bootstrapping services for local use...');
      // Wait for authenticated services to complete initialization
      // with timeout to prevent blocking forever
      try {
        await setupAuthenticatedServices().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint(
                '[Locator] ⚠ Authenticated services initialization timed out after 30s');
            // Don't throw - allow app to continue with core services
          },
        );
        debugPrint('[Locator] ✓ Authenticated services initialized');
      } catch (e, stack) {
        debugPrint(
            '[Locator] ⚠ Authenticated services initialization failed: $e');
        debugPrint('[Locator] Stack trace: $stack');
        // Don't rethrow - allow app to continue with core services
      }
    }
  } catch (e, stack) {
    debugPrint('[Locator] ❌ CRITICAL ERROR initializing AuthService: $e');
    debugPrint('[Locator] Stack trace: $stack');
    rethrow;
  }

  debugPrint('[ServiceLocator] ===== REGISTERING CORE SERVICES END =====');

  // Verify all core services are registered
  _verifyCoreServicesRegistered();

  // Only mark as registered if we got this far without exceptions
  _coreServicesRegistered = true;
  debugPrint(
      '[ServiceLocator] Core services registration completed successfully');
}

/// Verify that all critical core services are registered
void _verifyCoreServicesRegistered() {
  final criticalServices = [
    'AuthService',
    'ThemeProvider',
    'ProviderConfigurationManager',
    'DesktopClientDetectionService',
    'AppInitializationService',
  ];

  debugPrint('[ServiceLocator] Verifying core services registration...');
  bool allServicesRegistered = true;

  for (final serviceName in criticalServices) {
    try {
      bool isRegistered = false;
      switch (serviceName) {
        case 'AuthService':
          isRegistered = serviceLocator.isRegistered<AuthService>();
          break;
        case 'ThemeProvider':
          isRegistered = serviceLocator.isRegistered<ThemeProvider>();
          break;
        case 'ProviderConfigurationManager':
          isRegistered =
              serviceLocator.isRegistered<ProviderConfigurationManager>();
          break;
        case 'DesktopClientDetectionService':
          isRegistered =
              serviceLocator.isRegistered<DesktopClientDetectionService>();
          break;
        case 'AppInitializationService':
          isRegistered =
              serviceLocator.isRegistered<AppInitializationService>();
          break;
      }

      if (isRegistered) {
        debugPrint('[ServiceLocator] ✓ $serviceName registered');
      } else {
        debugPrint('[ServiceLocator] ✗ $serviceName NOT registered');
        allServicesRegistered = false;
      }
    } catch (e) {
      debugPrint('[ServiceLocator] Error checking $serviceName: $e');
      allServicesRegistered = false;
    }
  }

  if (!allServicesRegistered) {
    throw Exception('Critical core services failed to register properly');
  }
}

/// Registers authenticated services that require authentication tokens.
/// These services should only be registered after the user has authenticated.
/// This prevents unnecessary initialization and improves security.
Future<void> setupAuthenticatedServices() async {
  if (_authenticatedServicesRegistered) {
    debugPrint(
        '[ServiceLocator] Authenticated services already registered (Early Exit)');
    // Services are already registered, so we're done
    return;
  }

  if (_isRegisteringAuthenticatedServices) {
    debugPrint(
        '[ServiceLocator] Authenticated services registration already in progress (Race Condition Avoided)');
    return;
  }

  _isRegisteringAuthenticatedServices = true;

  try {
    debugPrint(
        '[ServiceLocator] ===== REGISTERING AUTHENTICATED SERVICES START =====');
    debugPrint('[Locator] setupAuthenticatedServices called (Entry Point)');

    // Verify authentication before proceeding
    debugPrint('[Locator] Getting AuthService from serviceLocator...');
    final authService = serviceLocator.get<AuthService>();
    debugPrint('[Locator] Got AuthService instance');

    debugPrint('[ServiceLocator] Registering authenticated services...');
    _authenticatedServicesRegistered = true;

    final providerDiscoveryService =
        serviceLocator.get<ProviderDiscoveryService>();
    final enhancedUserTierService =
        serviceLocator.get<EnhancedUserTierService>();
    final webDownloadPromptService =
        serviceLocator.get<WebDownloadPromptService>();

    // Initialize enhanced user tier service now that we have auth
    debugPrint('[ServiceLocator] Initializing EnhancedUserTierService...');
    unawaited(enhancedUserTierService.initialize());

    // Initialize web download prompt service
    debugPrint('[ServiceLocator] Initializing WebDownloadPromptService...');
    await webDownloadPromptService.initialize();

    // LangChain Prompt Service is already initialized in constructor

    // Initialize Provider Discovery Service and auto-configure discovered providers
    debugPrint('[ServiceLocator] Initializing ProviderDiscoveryService...');
    await _initializeProviderDiscoveryAndAutoConfig(
      providerDiscoveryService,
      serviceLocator.get<ProviderConfigurationManager>(),
    );

    // Tunnel configuration manager - requires SharedPreferences
    debugPrint('[ServiceLocator] Initializing TunnelConfigManager...');
    final tunnelConfigManager = TunnelConfigManager();
    await tunnelConfigManager.initialize();
    serviceLocator.registerSingleton<TunnelConfigManager>(tunnelConfigManager);

    // Tunnel service - requires authentication token
    final tunnelService = TunnelService(authService: authService);
    serviceLocator.registerSingleton<TunnelService>(tunnelService);

    // Streaming proxy service - requires authentication token
    final streamingProxyService =
        StreamingProxyService(authService: authService);
    serviceLocator.registerSingleton<StreamingProxyService>(
      streamingProxyService,
    );

    // User container service - requires authentication token
    final userContainerService = UserContainerService(authService: authService);
    serviceLocator
        .registerSingleton<UserContainerService>(userContainerService);

    // LangChain integration service - requires authentication for provider access
    debugPrint('[ServiceLocator] Initializing LangChainIntegrationService...');
    final langchainIntegrationService = LangChainIntegrationService();
    try {
      await langchainIntegrationService
          .initializeProviders()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: LangChainIntegrationService initialization failed: $e');
    }
    serviceLocator.registerSingleton<LangChainIntegrationService>(
      langchainIntegrationService,
    );

    // LLM Provider Manager - requires authentication
    debugPrint('[ServiceLocator] Initializing LLMProviderManager...');
    final llmProviderManager = LLMProviderManager(
      discoveryService: providerDiscoveryService,
      langchainService: langchainIntegrationService,
    );
    try {
      await llmProviderManager
          .initialize()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: LLMProviderManager initialization failed: $e');
    }
    serviceLocator.registerSingleton<LLMProviderManager>(llmProviderManager);

    // Connection Manager - requires authentication for tunnel/cloud connections
    final settingsPreferenceService = serviceLocator<SettingsPreferenceService>();
    final connectionManager = ConnectionManagerService(
      tunnelService: tunnelService,
      authService: authService,
      settings: settingsPreferenceService,
    );
    try {
      await connectionManager.initialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: ConnectionManagerService initialization failed: $e');
    }
    serviceLocator
        .registerSingleton<ConnectionManagerService>(connectionManager);

    // LangChain RAG service - requires connection manager
    final langchainRagService = LangChainRAGService();
    try {
      await langchainRagService
          .initialize()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: LangChainRAGService initialization failed: $e');
    }
    serviceLocator.registerSingleton<LangChainRAGService>(langchainRagService);

    // LLM Audit service - requires authentication
    final llmAuditService = LLMAuditService(authService: authService);
    try {
      await llmAuditService.initialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: LLMAuditService initialization failed: $e');
    }
    serviceLocator.registerSingleton<LLMAuditService>(llmAuditService);

    // Streaming chat service - requires connection manager
    final streamingChatService = StreamingChatService(
      connectionManager,
      authService,
    );
    serviceLocator
        .registerSingleton<StreamingChatService>(streamingChatService);

    // Unified connection service - requires connection manager
    debugPrint('[ServiceLocator] Initializing UnifiedConnectionService...');
    final unifiedConnectionService = UnifiedConnectionService();
    unifiedConnectionService.setConnectionManager(connectionManager);
    try {
      await unifiedConnectionService
          .initialize()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: UnifiedConnectionService initialization failed: $e');
    }
    serviceLocator.registerSingleton<UnifiedConnectionService>(
      unifiedConnectionService,
    );

    // Agent Status Service - monitors OpenClaw Gateway agent status
    debugPrint('[ServiceLocator] Initializing AgentStatusService...');
    final localBrain = serviceLocator.get<LocalBrain>();
    final agentStatusService = AgentStatusService(db: localBrain);
    serviceLocator.registerSingleton<AgentStatusService>(agentStatusService);

    // Agent Lifecycle Service - manages agent start/stop/restart operations
    debugPrint('[ServiceLocator] Initializing AgentLifecycleService...');
    final agentLifecycleService = AgentLifecycleService(
      connectionManager: connectionManager,
    );
    serviceLocator
        .registerSingleton<AgentLifecycleService>(agentLifecycleService);

    // Admin services - require authentication and admin privileges
    final adminService = AdminService(authService: authService);
    serviceLocator.registerSingleton<AdminService>(adminService);

    final adminDataFlushService =
        AdminDataFlushService(authService: authService);
    serviceLocator.registerSingleton<AdminDataFlushService>(
      adminDataFlushService,
    );

    // Admin center service - requires authentication
    final adminCenterService = AdminCenterService(authService: authService);
    serviceLocator.registerSingleton<AdminCenterService>(adminCenterService);

    // Google Workspace service - handles personal Gmail/Calendar integrations
    final googleWorkspaceService = GoogleWorkspaceService(
      tokenStorage: serviceLocator.get<TokenStorageService>(),
    );
    serviceLocator
        .registerSingleton<GoogleWorkspaceService>(googleWorkspaceService);

    debugPrint(
        '[ServiceLocator] Authenticated services registered successfully');
    debugPrint(
        '[ServiceLocator] ===== REGISTERING AUTHENTICATED SERVICES END =====');
  } finally {
    _isRegisteringAuthenticatedServices = false;
  }
}

/// Initialize provider discovery and auto-configure discovered providers
Future<void> _initializeProviderDiscoveryAndAutoConfig(
  ProviderDiscoveryService discoveryService,
  ProviderConfigurationManager configManager,
) async {
  try {
    debugPrint('[ServiceLocator] Starting provider discovery scan...');

    // Scan for available providers
    final discoveredProviders = await discoveryService.scanForProviders();
    debugPrint(
        '[ServiceLocator] Found ${discoveredProviders.length} providers');

    // Auto-configure discovered providers if not already configured
    for (final providerInfo in discoveredProviders) {
      final providerId = 'auto_${providerInfo.id}';

      // Skip if already configured
      if (configManager.isProviderConfigured(providerId)) {
        debugPrint(
            '[ServiceLocator] Provider ${providerInfo.name} already configured, skipping');
        continue;
      }

      debugPrint('[ServiceLocator] Auto-configuring ${providerInfo.name}...');

      try {
        ProviderConfiguration? config;

        switch (providerInfo.type) {
          case ProviderType.ollama:
            config = OllamaProviderConfiguration(
              providerId: providerId,
              baseUrl: providerInfo.baseUrl,
              port: providerInfo.port,
              timeout: const Duration(seconds: 60),
              enableStreaming: true,
              enableEmbeddings: true,
              customSettings: {
                'auto_configured': true,
                'discovered_at': DateTime.now().toIso8601String(),
                'version': providerInfo.version,
                'models': providerInfo.availableModels,
              },
            );
            break;

          case ProviderType.lmStudio:
            config = LMStudioProviderConfiguration(
              providerId: providerId,
              baseUrl: providerInfo.baseUrl,
              port: providerInfo.port,
              timeout: const Duration(seconds: 120),
              enableStreaming: true,
              customSettings: {
                'auto_configured': true,
                'discovered_at': DateTime.now().toIso8601String(),
                'models': providerInfo.availableModels,
              },
            );
            break;

          case ProviderType.openAICompatible:
            config = OpenAICompatibleProviderConfiguration(
              providerId: providerId,
              baseUrl: providerInfo.baseUrl,
              port: providerInfo.port,
              timeout: const Duration(seconds: 90),
              requiresAuth: false,
              enableStreaming: true,
              customSettings: {
                'auto_configured': true,
                'discovered_at': DateTime.now().toIso8601String(),
                'models': providerInfo.availableModels,
              },
            );
            break;

          case ProviderType.custom:
            // Skip custom providers for auto-configuration
            debugPrint(
                '[ServiceLocator] Skipping custom provider ${providerInfo.name}');
            continue;
        }

        await configManager.setConfiguration(config);
        debugPrint(
            '[ServiceLocator] ✓ Auto-configured ${providerInfo.name} as $providerId');

        // Set Ollama as default provider if found and no preferred provider is set
        if (providerInfo.type == ProviderType.ollama &&
            configManager.preferredProviderId == null) {
          await configManager.setPreferredProvider(providerId);
          debugPrint('[ServiceLocator] ✓ Set Ollama as default provider');
        }
      } catch (e) {
        debugPrint(
            '[ServiceLocator] Failed to auto-configure ${providerInfo.name}: $e');
      }
    }

    // Start periodic scanning for new providers
    discoveryService.startPeriodicScanning();
    debugPrint('[ServiceLocator] Started periodic provider scanning');
  } catch (e) {
    debugPrint(
        '[ServiceLocator] Error during provider discovery initialization: $e');
  }
}

/// Legacy function for backward compatibility.
/// Now delegates to setupCoreServices() to maintain existing code.
Future<void> setupServiceLocator() async {
  await setupCoreServices();
}
