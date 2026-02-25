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
import 'package:cloudtolocalllm/services/langchain_prompt_service.dart';
import 'package:cloudtolocalllm/services/langchain_rag_service.dart';
import 'package:cloudtolocalllm/services/llm_audit_service.dart';
import 'package:cloudtolocalllm/services/llm_error_handler.dart';
import 'package:cloudtolocalllm/services/llm_provider_manager.dart';
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

    // Core services that extend ChangeNotifier
    _addChangeNotifierProvider<DesktopClientDetectionService>(providers);
    _addChangeNotifierProvider<AppInitializationService>(providers);
    _addChangeNotifierProvider<EnhancedUserTierService>(providers);
    _addChangeNotifierProvider<ThemeProvider>(providers);

    // Core services that don't extend ChangeNotifier - use regular Provider
    _addProviderIfRegisteredNoChangeNotifier<AuthService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<WebDownloadPromptService>(
        providers);
    _addProviderIfRegisteredNoChangeNotifier<ProviderDiscoveryService>(
        providers);
    _addProviderIfRegisteredNoChangeNotifier<LLMErrorHandler>(providers);
    _addProviderIfRegisteredNoChangeNotifier<LangChainPromptService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<ProviderConfigurationManager>(
        providers);

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

    // Authenticated services - use regular Provider as they don't extend ChangeNotifier
    _addProviderIfRegisteredNoChangeNotifier<TunnelService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<StreamingProxyService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<UserContainerService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<LangChainIntegrationService>(
        providers);
    _addProviderIfRegisteredNoChangeNotifier<LLMProviderManager>(providers);
    _addProviderIfRegisteredNoChangeNotifier<ConnectionManagerService>(
        providers);
    _addProviderIfRegisteredNoChangeNotifier<LangChainRAGService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<LLMAuditService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<StreamingChatService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<UnifiedConnectionService>(
        providers);
    _addProviderIfRegisteredNoChangeNotifier<AdminService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<AdminDataFlushService>(providers);
    _addProviderIfRegisteredNoChangeNotifier<AdminCenterService>(providers);

    return providers;
  }

  void _addChangeNotifierProvider<T extends ChangeNotifier>(
      List<SingleChildWidget> providers) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(ChangeNotifierProvider<T>.value(value: service));
      }
    } catch (e) {
      debugPrint('[Providers] Error adding ChangeNotifier provider $T: $e');
    }
  }

  void _addProviderIfRegisteredNoChangeNotifier<T extends Object>(
      List<SingleChildWidget> providers) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(Provider<T>.value(value: service));
      }
    } catch (e) {
      debugPrint('[Providers] Error adding provider $T: $e');
    }
  }
}
