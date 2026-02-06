import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:zoidbot/services/admin_data_flush_service.dart';
import 'package:zoidbot/services/admin_service.dart';
import 'package:zoidbot/services/app_initialization_service.dart';
import 'package:zoidbot/services/auth_service.dart';
import 'package:zoidbot/services/session_storage_service.dart';
import 'package:zoidbot/services/connection_manager_service.dart';
import 'package:zoidbot/auth/auth_provider.dart';
import 'package:zoidbot/auth/providers/auth0_auth_provider.dart';
import 'package:zoidbot/services/desktop_client_detection_service.dart';
import 'package:zoidbot/services/enhanced_user_tier_service.dart';
import 'package:zoidbot/services/langchain_integration_service.dart';
import 'package:zoidbot/services/langchain_prompt_service.dart';
import 'package:zoidbot/services/langchain_rag_service.dart'
    if (dart.library.html) 'package:zoidbot/services/langchain_rag_service_stub.dart';
import 'package:zoidbot/services/llm_audit_service.dart';
import 'package:zoidbot/services/llm_error_handler.dart';
import 'package:zoidbot/services/llm_provider_manager.dart';
import 'package:zoidbot/services/provider_discovery_service.dart';
import 'package:zoidbot/services/streaming_chat_service.dart';
import 'package:zoidbot/services/streaming_proxy_service.dart';
import 'package:zoidbot/services/tunnel_service.dart';
import 'package:zoidbot/services/tunnel/tunnel_config_manager.dart';
import 'package:zoidbot/services/unified_connection_service.dart';
import 'package:zoidbot/services/user_container_service.dart';
import 'package:zoidbot/services/web_download_prompt_service.dart'
    if (dart.library.io) 'package:zoidbot/services/web_download_prompt_service_stub.dart';
import 'package:zoidbot/services/settings_preference_service.dart';
import 'package:zoidbot/services/settings_import_export_service.dart';
import 'package:zoidbot/services/provider_configuration_manager.dart';
import 'package:zoidbot/services/admin_center_service.dart';
import 'package:zoidbot/services/theme_provider.dart';
import 'package:zoidbot/services/platform_detection_service.dart';
import 'package:zoidbot/services/platform_adapter.dart';
import 'package:zoidbot/services/url_scheme_registration_service.dart';
import 'package:zoidbot/services/token_storage_service.dart';
import 'package:zoidbot/models/provider_configuration.dart';
import 'package:zoidbot/services/langchain_ollama_service.dart';

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
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
final openClawDashboardClientService = OpenClawDashboardService();
serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);

// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    return;
  }

  debugPrint('[ServiceLocator] ===== REGISTERING CORE SERVICES START =====');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  debugPrint('[ServiceLocator] Registering core services...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Settings preference service - manages user preferences
  // Register this early as other services (like AuthProvider) may need it
  final settingsPreferenceService = SettingsPreferenceService();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<SettingsPreferenceService>(
    settingsPreferenceService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Session storage service for PostgreSQL session management
  final sessionStorageService = SessionStorageService();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator
      .registerSingleton<SessionStorageService>(sessionStorageService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Token storage service for encrypted local persistence (SQLite)
  final tokenStorageService = TokenStorageService();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  await tokenStorageService.init();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);
  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<TokenStorageService>(tokenStorageService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Provider discovery - create but don't initialize until auth
  final providerDiscoveryService = ProviderDiscoveryService();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<ProviderDiscoveryService>(
    providerDiscoveryService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Authentication Provider - Using platform-specific provider
  late AuthProvider authProvider;

  try {
    debugPrint('[Locator] Detecting platform...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Check if we're on web first
    if (kIsWeb) {
      debugPrint('[Locator] ✓ Web platform detected, using Auth0AuthProvider');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
      authProvider = Auth0AuthProvider();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    } else {
      // Use Auth0AuthProvider for all desktop platforms
      debugPrint('[Locator] Using Auth0AuthProvider for desktop');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
      authProvider = Auth0AuthProvider();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    }
  } catch (e, stack) {
    debugPrint('[Locator] ERROR during platform detection: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] Stack trace: $stack');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    // Fallback to Auth0 if platform detection fails
    debugPrint('[Locator] Falling back to Auth0AuthProvider');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    authProvider = Auth0AuthProvider();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  }

  debugPrint('[Locator] Selected auth provider: ${authProvider.runtimeType}');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Register strictly as AuthProvider interface to enforce abstraction
  try {
    debugPrint('[Locator] Registering AuthProvider...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator.registerSingleton<AuthProvider>(authProvider);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] ✓ AuthProvider registered successfully');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  } catch (e, stack) {
    debugPrint('[Locator] ❌ CRITICAL ERROR registering AuthProvider: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] Stack trace: $stack');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    rethrow;
  }

  late final AuthService authService;
  try {
    debugPrint('[Locator] Registering AuthService...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    authService = AuthService(authProvider);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator.registerSingleton<AuthService>(authService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] ✓ AuthService registered successfully');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  } catch (e, stack) {
    debugPrint('[Locator] ❌ CRITICAL ERROR registering AuthService: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] Stack trace: $stack');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    rethrow;
  }

  // LLM Error Handler - lightweight, doesn't require auth
  final llmErrorHandler = LLMErrorHandler(
    providerDiscovery: providerDiscoveryService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<LLMErrorHandler>(llmErrorHandler);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // LangChain Prompt Service - create but don't initialize templates until auth
  final langchainPromptService = LangChainPromptService();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<LangChainPromptService>(
    langchainPromptService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Desktop client detection - can check client type without auth
  final desktopClientDetectionService = DesktopClientDetectionService(
    authService: authService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<DesktopClientDetectionService>(
    desktopClientDetectionService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // App initialization service - manages initialization order
  final appInitializationService = AppInitializationService(
    authService: authService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<AppInitializationService>(
    appInitializationService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Settings import/export service - handles settings backup/restore
  final settingsImportExportService = SettingsImportExportService(
    preferencesService: settingsPreferenceService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<SettingsImportExportService>(
    settingsImportExportService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Platform detection service - detects current platform and provides platform info
  final platformDetectionService = PlatformDetectionService();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<PlatformDetectionService>(
    platformDetectionService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Platform adapter - provides platform-appropriate UI components
  final platformAdapter = PlatformAdapter(platformDetectionService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<PlatformAdapter>(platformAdapter);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Theme provider - manages application theme mode
  final themeProvider = ThemeProvider();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<ThemeProvider>(themeProvider);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Provider configuration manager - manages local LLM provider configurations
// OpenClaw dashboard client service
/final openClawDashboardClientService = OpenClawDashboardService();/
// OpenClaw dashboard client service
  final providerConfigurationManager = ProviderConfigurationManager();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<ProviderConfigurationManager>(
    providerConfigurationManager,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // URL scheme registration service - registers custom URL schemes for OAuth callbacks (Windows)
  serviceLocator.registerSingleton<UrlSchemeRegistrationService>(
    UrlSchemeRegistrationService(),
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Web download prompt service - can be created but won't do heavy work until auth
  final webDownloadPromptService = WebDownloadPromptService(
    authService: authService,
    clientDetectionService: desktopClientDetectionService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  // Don't initialize yet - wait for auth
  serviceLocator.registerSingleton<WebDownloadPromptService>(
    webDownloadPromptService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Enhanced user tier service - can be created but won't initialize until auth
  final enhancedUserTierService = EnhancedUserTierService(
    authService: authService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<EnhancedUserTierService>(
    enhancedUserTierService,
  );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Don't initialize yet - wait for auth token

  debugPrint('[ServiceLocator] Core services registered successfully');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Initialize AuthService last, after all dependencies are registered
  try {
    debugPrint('[Locator] Initializing AuthService...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    final authService = serviceLocator.get<AuthService>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    await authService.init();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] ✓ AuthService initialized successfully');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  } catch (e, stack) {
    debugPrint('[Locator] ❌ CRITICAL ERROR initializing AuthService: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] Stack trace: $stack');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    rethrow;
  }

  debugPrint('[ServiceLocator] ===== REGISTERING CORE SERVICES END =====');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Verify all core services are registered
  _verifyCoreServicesRegistered();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

  // Only mark as registered if we got this far without exceptions
  _coreServicesRegistered = true;
  debugPrint(
      '[ServiceLocator] Core services registration completed successfully');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
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
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  bool allServicesRegistered = true;

  for (final serviceName in criticalServices) {
    try {
      bool isRegistered = false;
      switch (serviceName) {
        case 'AuthService':
          isRegistered = serviceLocator.isRegistered<AuthService>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
          break;
        case 'ThemeProvider':
          isRegistered = serviceLocator.isRegistered<ThemeProvider>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
          break;
        case 'ProviderConfigurationManager':
          isRegistered =
              serviceLocator.isRegistered<ProviderConfigurationManager>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
          break;
        case 'DesktopClientDetectionService':
          isRegistered =
              serviceLocator.isRegistered<DesktopClientDetectionService>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
          break;
        case 'AppInitializationService':
          isRegistered =
              serviceLocator.isRegistered<AppInitializationService>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
          break;
      }

      if (isRegistered) {
        debugPrint('[ServiceLocator] ✓ $serviceName registered');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
      } else {
        debugPrint('[ServiceLocator] ✗ $serviceName NOT registered');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
        allServicesRegistered = false;
      }
    } catch (e) {
      debugPrint('[ServiceLocator] Error checking $serviceName: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
      allServicesRegistered = false;
    }
  }

  if (!allServicesRegistered) {
    throw Exception('Critical core services failed to register properly');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  }
}

/// Registers authenticated services that require authentication tokens.
/// These services should only be registered after the user has authenticated.
/// This prevents unnecessary initialization and improves security.
Future<void> setupAuthenticatedServices() async {
  if (_authenticatedServicesRegistered) {
    debugPrint(
        '[ServiceLocator] Authenticated services already registered (Early Exit)');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    // Services are already registered, so we're done
    return;
  }

  if (_isRegisteringAuthenticatedServices) {
    debugPrint(
        '[ServiceLocator] Authenticated services registration already in progress (Race Condition Avoided)');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    return;
  }

  _isRegisteringAuthenticatedServices = true;

  try {
    debugPrint(
        '[ServiceLocator] ===== REGISTERING AUTHENTICATED SERVICES START =====');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] setupAuthenticatedServices called (Entry Point)');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Verify authentication before proceeding
    debugPrint('[Locator] Getting AuthService from serviceLocator...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    final authService = serviceLocator.get<AuthService>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[Locator] Got AuthService instance');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    debugPrint('[ServiceLocator] Registering authenticated services...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    _authenticatedServicesRegistered = true;

    final providerDiscoveryService =
        serviceLocator.get<ProviderDiscoveryService>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    final enhancedUserTierService =
        serviceLocator.get<EnhancedUserTierService>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    final webDownloadPromptService =
        serviceLocator.get<WebDownloadPromptService>();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Initialize enhanced user tier service now that we have auth
    debugPrint('[ServiceLocator] Initializing EnhancedUserTierService...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    unawaited(enhancedUserTierService.initialize());
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Initialize web download prompt service
    debugPrint('[ServiceLocator] Initializing WebDownloadPromptService...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    await webDownloadPromptService.initialize();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // LangChain Prompt Service is already initialized in constructor

    // Initialize Provider Discovery Service and auto-configure discovered providers
    debugPrint('[ServiceLocator] Initializing ProviderDiscoveryService...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    await _initializeProviderDiscoveryAndAutoConfig(
      providerDiscoveryService,
      serviceLocator.get<ProviderConfigurationManager>(),
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Tunnel configuration manager - requires SharedPreferences
    debugPrint('[ServiceLocator] Initializing TunnelConfigManager...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    final tunnelConfigManager = TunnelConfigManager();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    await tunnelConfigManager.initialize();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator.registerSingleton<TunnelConfigManager>(tunnelConfigManager);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Tunnel service - requires authentication token
    final tunnelService = TunnelService(authService: authService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator.registerSingleton<TunnelService>(tunnelService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Streaming proxy service - requires authentication token
    final streamingProxyService =
        StreamingProxyService(authService: authService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator.registerSingleton<StreamingProxyService>(
      streamingProxyService,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // User container service - requires authentication token
    final userContainerService = UserContainerService(authService: authService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator
        .registerSingleton<UserContainerService>(userContainerService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // LangChain integration service - requires authentication for provider access
    debugPrint('[ServiceLocator] Initializing LangChainIntegrationService...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    final langchainIntegrationService = LangChainIntegrationService(
      discoveryService: providerDiscoveryService,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    try {
      await langchainIntegrationService
          .initializeProviders()
          .timeout(const Duration(seconds: 10));
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: LangChainIntegrationService initialization failed: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    }
    serviceLocator.registerSingleton<LangChainIntegrationService>(
      langchainIntegrationService,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // LLM Provider Manager - requires authentication
    debugPrint('[ServiceLocator] Initializing LLMProviderManager...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    final llmProviderManager = LLMProviderManager(
      discoveryService: providerDiscoveryService,
      langchainService: langchainIntegrationService,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    try {
      await llmProviderManager
          .initialize()
          .timeout(const Duration(seconds: 10));
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: LLMProviderManager initialization failed: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    }
    serviceLocator.registerSingleton<LLMProviderManager>(llmProviderManager);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Connection Manager - requires authentication for tunnel/cloud connections
    final connectionManager = ConnectionManagerService(
      tunnelService: tunnelService,
      authService: authService,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    try {
      await connectionManager.initialize().timeout(const Duration(seconds: 10));
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: ConnectionManagerService initialization failed: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    }
    serviceLocator
        .registerSingleton<ConnectionManagerService>(connectionManager);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // LangChain RAG service - requires connection manager
    final langchainRagService = LangChainRAGService(
      connectionManager: connectionManager,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    try {
      await langchainRagService
          .initialize()
          .timeout(const Duration(seconds: 10));
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: LangChainRAGService initialization failed: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    }
    serviceLocator.registerSingleton<LangChainRAGService>(langchainRagService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // LLM Audit service - requires authentication
    final llmAuditService = LLMAuditService(authService: authService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    try {
      await llmAuditService.initialize().timeout(const Duration(seconds: 10));
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: LLMAuditService initialization failed: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    }
    serviceLocator.registerSingleton<LLMAuditService>(llmAuditService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Streaming chat service - requires connection manager
    final streamingChatService = StreamingChatService(
      connectionManager,
      authService,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator
        .registerSingleton<StreamingChatService>(streamingChatService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Unified connection service - requires connection manager
    debugPrint('[ServiceLocator] Initializing UnifiedConnectionService...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    final unifiedConnectionService = UnifiedConnectionService();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    unifiedConnectionService.setConnectionManager(connectionManager);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    try {
      await unifiedConnectionService
          .initialize()
          .timeout(const Duration(seconds: 10));
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    } catch (e) {
      debugPrint(
          '[ServiceLocator] Warning: UnifiedConnectionService initialization failed: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    }
    serviceLocator.registerSingleton<UnifiedConnectionService>(
      unifiedConnectionService,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Admin services - require authentication and admin privileges
    final adminService = AdminService(authService: authService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator.registerSingleton<AdminService>(adminService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    final adminDataFlushService =
        AdminDataFlushService(authService: authService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator.registerSingleton<AdminDataFlushService>(
      adminDataFlushService,
    );
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Admin center service - requires authentication
    final adminCenterService = AdminCenterService(authService: authService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    serviceLocator.registerSingleton<AdminCenterService>(adminCenterService);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    debugPrint(
        '[ServiceLocator] Authenticated services registered successfully');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint(
        '[ServiceLocator] ===== REGISTERING AUTHENTICATED SERVICES END =====');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
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
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Scan for available providers
    final discoveredProviders = await discoveryService.scanForProviders();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint(
        '[ServiceLocator] Found ${discoveredProviders.length} providers');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

    // Auto-configure discovered providers if not already configured
    for (final providerInfo in discoveredProviders) {
      final providerId = 'auto_${providerInfo.id}';

      // Skip if already configured
      if (configManager.isProviderConfigured(providerId)) {
        debugPrint(
            '[ServiceLocator] Provider ${providerInfo.name} already configured, skipping');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
        continue;
      }

      debugPrint('[ServiceLocator] Auto-configuring ${providerInfo.name}...');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

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
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
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
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
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
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
            break;

          case ProviderType.custom:
            // Skip custom providers for auto-configuration
            debugPrint(
                '[ServiceLocator] Skipping custom provider ${providerInfo.name}');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
            continue;
        }

        await configManager.setConfiguration(config);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
        debugPrint(
            '[ServiceLocator] ✓ Auto-configured ${providerInfo.name} as $providerId');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}

        // Set Ollama as default provider if found and no preferred provider is set
        if (providerInfo.type == ProviderType.ollama &&
            configManager.preferredProviderId == null) {
          await configManager.setPreferredProvider(providerId);
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
          debugPrint('[ServiceLocator] ✓ Set Ollama as default provider');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
        }
      } catch (e) {
        debugPrint(
            '[ServiceLocator] Failed to auto-configure ${providerInfo.name}: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
      }
    }

    // Start periodic scanning for new providers
    discoveryService.startPeriodicScanning();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
    debugPrint('[ServiceLocator] Started periodic provider scanning');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  } catch (e) {
    debugPrint(
        '[ServiceLocator] Error during provider discovery initialization: $e');
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  }
}

/// Legacy function for backward compatibility.
/// Now delegates to setupCoreServices() to maintain existing code.
Future<void> setupServiceLocator() async {
  await setupCoreServices();
// OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardService();

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
  serviceLocator.registerSingleton<OpenClawDashboardService>(openClawDashboardClientService);

  // OpenClaw dashboard client service - manages WebSocket connection to OpenClaw agent dashboard
  final openClawDashboardClientService = OpenClawDashboardClientService();
  serviceLocator.registerSingleton<OpenClawDashboardClientService>(openClawDashboardClientService);
}
}
