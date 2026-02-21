/// LLM Error Handler
/// Handles and categorizes LLM provider errors
library;

import 'package:cloudtolocalllm/services/provider_discovery_service.dart';

class LLMErrorHandler {
  LLMErrorHandler({ProviderDiscoveryService? providerDiscovery});

  /// Handle an error from an LLM provider
  String handleError(dynamic error, {String? providerId}) {
    // Stub - returns generic error message
    return 'An LLM error occurred';
  }

  /// Check if an error is retryable
  bool isRetryable(dynamic error) {
    // Stub - returns false
    return false;
  }

  /// Get user-friendly error message
  String getUserMessage(dynamic error) {
    // Stub - returns generic message
    return 'An error occurred while communicating with the LLM provider';
  }

  /// Log error for diagnostics
  Future<void> logError(dynamic error, {String? providerId}) async {
    // Stub - no-op
  }
}
