import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

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
import 'package:zoidbot/services/theme_provider.dart';
import 'package:zoidbot/services/platform_adapter.dart';
import 'package:zoidbot/services/platform_detection_service.dart';
import 'package:zoidbot/providers/agent_provider.dart';

class AppProviderBuilder {
  List<SingleChildWidget> buildProviders() {
    final providers = <SingleChildWidget>[];

    // Core services
    providers.add(ChangeNotifierProvider<AgentProvider>(create: (_) => AgentProvider()));
    _addCoreProvider<AuthService>(providers);
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
    } catch (e) {
      debugPrint('[Providers] Error adding PlatformAdapter: $e');
    }

    // Authenticated services
    _addProviderIfRegistered<TunnelService>(providers);
    _addProviderIfRegistered<StreamingProxyService>(providers);
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
    } catch (e) {
      debugPrint('[Providers] Error adding core provider $T: $e');
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
      debugPrint('[Providers] Error adding provider $T: $e');
    }
  }
}
