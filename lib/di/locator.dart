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

import 'package:zoidbot/services/admin_center_service.dart';
import 'package:zoidbot/services/theme_provider.dart';
import 'package:zoidbot/services/platform_detection_service.dart';
import 'package:zoidbot/services/platform_adapter.dart';
import 'package:zoidbot/services/url_scheme_registration_service.dart';
import 'package:zoidbot/services/token_storage_service.dart';
import 'package:zoidbot/services/openclaw_gateway_service.dart';
import 'package:zoidbot/services/system_control_service.dart';
import 'package:zoidbot/services/window_manager_service.dart';

final GetIt serviceLocator = GetIt.instance;

bool _coreServicesRegistered = false;
bool _authenticatedServicesRegistered = false;
bool _isRegisteringAuthenticatedServices = false;

/// Registers core services that are needed before authentication.
Future<void> setupCoreServices() async {
  if (_coreServicesRegistered) return;

  debugPrint('[ServiceLocator] Registering core services...');

  final settingsPreferenceService = SettingsPreferenceService();
  serviceLocator.registerSingleton<SettingsPreferenceService>(settingsPreferenceService);

  final sessionStorageService = SessionStorageService();
  serviceLocator.registerSingleton<SessionStorageService>(sessionStorageService);

  final tokenStorageService = TokenStorageService();
  await tokenStorageService.init();
  serviceLocator.registerSingleton<TokenStorageService>(tokenStorageService);

  late AuthProvider authProvider;
  if (kIsWeb) {
    authProvider = Auth0AuthProvider();
  } else {
    authProvider = Auth0AuthProvider();
  }
  serviceLocator.registerSingleton<AuthProvider>(authProvider);

  final authService = AuthService(authProvider);
  serviceLocator.registerSingleton<AuthService>(authService);

  final desktopClientDetectionService = DesktopClientDetectionService(authService: authService);
  serviceLocator.registerSingleton<DesktopClientDetectionService>(desktopClientDetectionService);

  final appInitializationService = AppInitializationService(authService: authService);
  serviceLocator.registerSingleton<AppInitializationService>(appInitializationService);

  final settingsImportExportService = SettingsImportExportService(preferencesService: settingsPreferenceService);
  serviceLocator.registerSingleton<SettingsImportExportService>(settingsImportExportService);

  final platformDetectionService = PlatformDetectionService();
  serviceLocator.registerSingleton<PlatformDetectionService>(platformDetectionService);

  final platformAdapter = PlatformAdapter(platformDetectionService);
  serviceLocator.registerSingleton<PlatformAdapter>(platformAdapter);

  final themeProvider = ThemeProvider();
  serviceLocator.registerSingleton<ThemeProvider>(themeProvider);

  final windowManagerService = WindowManagerService();
  serviceLocator.registerSingleton<WindowManagerService>(windowManagerService);

  final systemControlService = SystemControlService();
  serviceLocator.registerSingleton<SystemControlService>(systemControlService);

  serviceLocator.registerSingleton<UrlSchemeRegistrationService>(UrlSchemeRegistrationService());

  final webDownloadPromptService = WebDownloadPromptService(
    authService: authService,
    clientDetectionService: desktopClientDetectionService,
  );
  serviceLocator.registerSingleton<WebDownloadPromptService>(webDownloadPromptService);

  final enhancedUserTierService = EnhancedUserTierService();
  serviceLocator.registerSingleton<EnhancedUserTierService>(enhancedUserTierService);

  final openClawGatewayService = OpenClawGatewayService();
  serviceLocator.registerSingleton<OpenClawGatewayService>(openClawGatewayService);

  await authService.init();

  _coreServicesRegistered = true;
}

/// Registers authenticated services that require authentication tokens.
Future<void> setupAuthenticatedServices() async {
  if (_authenticatedServicesRegistered || _isRegisteringAuthenticatedServices) return;

  _isRegisteringAuthenticatedServices = true;

  try {
    debugPrint('[ServiceLocator] Registering authenticated services...');
    final authService = serviceLocator.get<AuthService>();
    _authenticatedServicesRegistered = true;

    final webDownloadPromptService = serviceLocator.get<WebDownloadPromptService>();

    await webDownloadPromptService.initialize();

    final tunnelConfigManager = TunnelConfigManager();
    await tunnelConfigManager.initialize();
    serviceLocator.registerSingleton<TunnelConfigManager>(tunnelConfigManager);

    final tunnelService = TunnelService(authService: authService);
    serviceLocator.registerSingleton<TunnelService>(tunnelService);

    final streamingProxyService = StreamingProxyService(authService: authService);
    serviceLocator.registerSingleton<StreamingProxyService>(streamingProxyService);

    final userContainerService = UserContainerService(authService: authService);
    serviceLocator.registerSingleton<UserContainerService>(userContainerService);

    // Connection Manager - uses OpenClaw Gateway for all LLM providers
    final openClawGatewayService = serviceLocator.get<OpenClawGatewayService>();
    final connectionManager = ConnectionManagerService(
      authService: authService,
      gateway: openClawGatewayService,
    );
    await connectionManager.initialize();
    serviceLocator.registerSingleton<ConnectionManagerService>(connectionManager);

    final streamingChatService = StreamingChatService(
      connectionManager,
      authService,
    );
    serviceLocator.registerSingleton<StreamingChatService>(streamingChatService);

    final unifiedConnectionService = UnifiedConnectionService();
    unifiedConnectionService.setConnectionManager(connectionManager);
    serviceLocator.registerSingleton<UnifiedConnectionService>(unifiedConnectionService);

    final adminService = AdminService(authService: authService);
    serviceLocator.registerSingleton<AdminService>(adminService);

    final adminDataFlushService = AdminDataFlushService(authService: authService);
    serviceLocator.registerSingleton<AdminDataFlushService>(adminDataFlushService);

    final adminCenterService = AdminCenterService(authService: authService);
    serviceLocator.registerSingleton<AdminCenterService>(adminCenterService);

    debugPrint('[ServiceLocator] Authenticated services registered successfully');
  } finally {
    _isRegisteringAuthenticatedServices = false;
  }
}

Future<void> setupServiceLocator() async {
  await setupCoreServices();
}
