/// LLM Provider Manager
/// Manages LLM provider lifecycle and interactions
library;

import 'package:cloudtolocalllm/services/langchain_integration_service.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';

class LLMProviderManager {
  LLMProviderManager({
    required ProviderDiscoveryService discoveryService,
    required LangChainIntegrationService langchainService,
  });

  /// Initialize the provider manager
  Future<void> initialize() async {
    // Stub - no-op
  }

  /// Get all available providers
  List<String> getAvailableProviders() {
    // Stub - returns empty list
    return [];
  }

  /// Get provider status
  Future<Map<String, dynamic>> getProviderStatus(String providerId) async {
    // Stub - returns empty map
    return {};
  }

  /// Refresh provider connections
  Future<void> refreshProviders() async {
    // Stub - no-op
  }

  /// Shutdown all providers
  Future<void> shutdown() async {
    // Stub - no-op
  }
}
