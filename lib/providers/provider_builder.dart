import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

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
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';

class ProviderBuilder {
  List<SingleChildWidget> buildProviders() {
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

    try {
      if (di.serviceLocator.isRegistered<PlatformAdapter>()) {
        final platformAdapter = di.serviceLocator.get<PlatformAdapter>();
        providers.add(
          Provider<PlatformAdapter>.value(value: platformAdapter),
        );
      }
    } catch (e) {
      print('[Providers] Error adding PlatformAdapter: $e');
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
    } catch (e) {
      print('[Providers] Error adding core provider $T: $e');
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
