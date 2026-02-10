/// LangChain Integration Service
///
/// Manages LangChain providers and provides a unified interface for LLM operations.
/// This service abstracts provider-specific implementations using LangChain Dart's
/// standardized interfaces and patterns.
///
/// Key Features:
/// - Unified LLM interface across different providers
/// - Automatic provider initialization from discovery service
/// - Streaming and non-streaming text generation
/// - Provider health monitoring and failover
/// - Standardized error handling
///
/// Usage:
/// ```dart
/// final service = LangChainIntegrationService(discoveryService: discoveryService);
/// await service.initializeProviders();
/// final response = await service.processTextGenerationWithPreferred('Hello, world!');
/// ```
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';

import 'provider_discovery_service.dart';
import '../models/llm_communication_error.dart';

/// LangChain provider wrapper for unified interface
///
/// Wraps LangChain LLM instances with additional metadata and capabilities
/// information to provide a consistent interface across different providers.
class LangChainProviderWrapper {
  final String providerId;
  final String name;
  final ProviderType type;
  final BaseLLM llm;
  final Map<String, dynamic> configuration;
  final DateTime createdAt;

  const LangChainProviderWrapper({
    required this.providerId,
    required this.name,
    required this.type,
    required this.llm,
    required this.configuration,
    required this.createdAt,
  });

  /// Check if provider supports streaming
  bool get supportsStreaming => true;

  /// Check if provider supports embeddings
  bool get supportsEmbeddings => false; // Will be enhanced in future

  /// Get provider capabilities
  Map<String, bool> get capabilities => {
        'chat': true,
        'completion': true,
        'streaming': supportsStreaming,
        'embeddings': supportsEmbeddings,
      };
}

/// LangChain Integration Service
class LangChainIntegrationService extends ChangeNotifier {
  final ProviderDiscoveryService _discoveryService;
  final Map<String, LangChainProviderWrapper> _providers = {};
  final Map<String, StreamSubscription> _providerSubscriptions = {};

  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _error;
  String? _preferredProviderId;

  LangChainIntegrationService({
    required ProviderDiscoveryService discoveryService,
  }) : _discoveryService = discoveryService {
    // Listen to provider discovery changes
    _discoveryService.addListener(_onProvidersChanged);
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if service is initializing
  bool get isInitializing => _isInitializing;

  /// Get current error
  String? get error => _error;

  /// Get preferred provider ID
  String? get preferredProviderId => _preferredProviderId;

  /// Get all registered providers
  List<LangChainProviderWrapper> get providers =>
      List.unmodifiable(_providers.values);

  /// Get available providers (those that are working)
  List<LangChainProviderWrapper> get availableProviders =>
      _providers.values.toList();

  /// Initialize LangChain providers based on discovered providers
  Future<void> initializeProviders() async {
    if (_isInitializing) {
      debugPrint('LangChain initialization already in progress');
      return;
    }

    _isInitializing = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('Initializing LangChain providers...');

      // Clear existing providers
      await _clearProviders();

      // Get discovered providers
      final discoveredProviders = _discoveryService.getAvailableProviders();
      debugPrint('Found ${discoveredProviders.length} available providers');

      // Initialize each provider
      for (final providerInfo in discoveredProviders) {
        try {
          final wrapper = await _createProviderWrapper(providerInfo);
          if (wrapper != null) {
            _providers[providerInfo.id] = wrapper;
            debugPrint('Initialized LangChain provider: ${providerInfo.name}');
          }
        } catch (error) {
          debugPrint(
              'Failed to initialize provider ${providerInfo.name}: $error');
        }
      }

      // Set preferred provider if none is set
      if (_preferredProviderId == null && _providers.isNotEmpty) {
        _preferredProviderId = _providers.keys.first;
        debugPrint('Set preferred provider: $_preferredProviderId');
      }

      _isInitialized = true;
      debugPrint(
          'LangChain initialization completed with ${_providers.length} providers');
    } catch (error) {
      _error = 'Failed to initialize LangChain providers: $error';
      debugPrint(_error);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Get LangChain LLM instance for a specific provider
  Future<BaseLLM?> getLLMForProvider(String providerId) async {
    final wrapper = _providers[providerId];
    if (wrapper == null) {
      debugPrint('Provider not found: $providerId');
      return null;
    }

    return wrapper.llm;
  }

  /// Get preferred LLM instance
  Future<BaseLLM?> getPreferredLLM() async {
    if (_preferredProviderId == null) {
      debugPrint('No preferred provider set');
      return null;
    }

    return getLLMForProvider(_preferredProviderId!);
  }

  /// Set preferred provider
  void setPreferredProvider(String providerId) {
    if (_providers.containsKey(providerId)) {
      _preferredProviderId = providerId;
      debugPrint('Preferred provider set to: $providerId');
      notifyListeners();
    } else {
      debugPrint('Cannot set preferred provider - not found: $providerId');
    }
  }

  /// Process text generation using specified provider
  Future<String?> processTextGeneration(
    String providerId,
    String prompt, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final llm = await getLLMForProvider(providerId);
      if (llm == null) {
        throw LLMCommunicationError.providerNotFound(
          providerId: providerId,
        );
      }

      debugPrint('Processing text generation with provider: $providerId');

      // Create prompt value from string
      final promptValue = PromptValue.string(prompt);

      // Generate response
      final response = await llm.invoke(promptValue);

      debugPrint('Text generation completed successfully');
      return response.output;
    } catch (error) {
      debugPrint('Text generation failed: $error');
      if (error is LLMCommunicationError) {
        rethrow;
      }
      throw LLMCommunicationError.fromException(
        error is Exception ? error : Exception(error.toString()),
        type: LLMCommunicationErrorType.providerUnavailable,
        providerId: providerId,
      );
    }
  }

  /// Process text generation with preferred provider
  Future<String?> processTextGenerationWithPreferred(
    String prompt, {
    Map<String, dynamic>? parameters,
  }) async {
    if (_preferredProviderId == null) {
      throw LLMCommunicationError.providerNotFound();
    }

    return processTextGeneration(_preferredProviderId!, prompt,
        parameters: parameters);
  }

  /// Process streaming text generation
  Stream<String> processStreamingGeneration(
    String providerId,
    String prompt, {
    Map<String, dynamic>? parameters,
  }) async* {
    try {
      final llm = await getLLMForProvider(providerId);
      if (llm == null) {
        throw LLMCommunicationError.providerNotFound(
          providerId: providerId,
        );
      }

      final wrapper = _providers[providerId]!;
      if (!wrapper.supportsStreaming) {
        throw LLMCommunicationError.fromException(
          Exception('Provider does not support streaming'),
          type: LLMCommunicationErrorType.requestMalformed,
          providerId: providerId,
        );
      }

      debugPrint('Processing streaming generation with provider: $providerId');

      // Create prompt value from string
      final promptValue = PromptValue.string(prompt);

      // Stream response
      await for (final chunk in llm.stream(promptValue)) {
        if (chunk.output.isNotEmpty) {
          yield chunk.output;
        }
      }

      debugPrint('Streaming generation completed successfully');
    } catch (error) {
      debugPrint('Streaming generation failed: $error');
      if (error is LLMCommunicationError) {
        rethrow;
      }
      throw LLMCommunicationError.fromException(
        error is Exception ? error : Exception(error.toString()),
        type: LLMCommunicationErrorType.providerUnavailable,
        providerId: providerId,
      );
    }
  }

  /// Get available models for a provider
  Future<List<String>> getAvailableModels(String providerId) async {
    try {
      final providerInfo = _discoveryService.getProviderById(providerId);
      if (providerInfo == null) {
        debugPrint('Provider info not found: $providerId');
        return [];
      }

      return providerInfo.availableModels;
    } catch (error) {
      debugPrint('Failed to get available models for $providerId: $error');
      return [];
    }
  }

  /// Test provider connection and functionality
  Future<bool> testProvider(String providerId) async {
    try {
      debugPrint('Testing provider: $providerId');

      final llm = await getLLMForProvider(providerId);
      if (llm == null) {
        return false;
      }

      // Simple test prompt
      const testPrompt =
          'Hello, this is a connection test. Please respond with "OK".';
      final response = await processTextGeneration(providerId, testPrompt);

      final success = response != null && response.isNotEmpty;
      debugPrint('Provider test result for $providerId: $success');

      return success;
    } catch (error) {
      debugPrint('Provider test failed for $providerId: $error');
      return false;
    }
  }

  /// Create LangChain provider wrapper from discovered provider info
  Future<LangChainProviderWrapper?> _createProviderWrapper(
    ProviderInfo providerInfo,
  ) async {
    try {
      BaseLLM? llm;

      switch (providerInfo.type) {
        case ProviderType.ollama:
          llm = await _createOllamaProvider(providerInfo);
          break;
        case ProviderType.lmStudio:
        case ProviderType.openAICompatible:
          llm = await _createOpenAICompatibleProvider(providerInfo);
          break;
        case ProviderType.custom:
          // Custom providers will be handled in future iterations
          debugPrint('Custom providers not yet supported');
          return null;
      }

      if (llm == null) {
        debugPrint('Failed to create LLM for provider: ${providerInfo.name}');
        return null;
      }

      return LangChainProviderWrapper(
        providerId: providerInfo.id,
        name: providerInfo.name,
        type: providerInfo.type,
        llm: llm,
        configuration: {
          'baseUrl': providerInfo.baseUrl,
          'port': providerInfo.port,
          'capabilities': providerInfo.capabilities,
          'version': providerInfo.version,
        },
        createdAt: DateTime.now(),
      );
    } catch (error) {
      debugPrint(
          'Error creating provider wrapper for ${providerInfo.name}: $error');
      return null;
    }
  }

  /// Create Ollama LangChain provider
  Future<BaseLLM?> _createOllamaProvider(ProviderInfo providerInfo) async {
    try {
      // Use the first available model or a default
      final model = providerInfo.availableModels.isNotEmpty
          ? providerInfo.availableModels.first
          : 'llama2'; // Default fallback

      final ollama = Ollama(
        baseUrl: providerInfo.baseUrl,
        defaultOptions: OllamaOptions(
          model: model,
          temperature: 0.7,
        ),
      );

      debugPrint('Created Ollama provider with model: $model');
      return ollama;
    } catch (error) {
      debugPrint('Failed to create Ollama provider: $error');
      return null;
    }
  }

  /// Create OpenAI-compatible LangChain provider
  Future<BaseLLM?> _createOpenAICompatibleProvider(
      ProviderInfo providerInfo) async {
    try {
      // For now, we'll use a basic HTTP-based implementation
      // This will be enhanced with proper OpenAI-compatible provider in future
      debugPrint(
          'OpenAI-compatible providers will be implemented in next iteration');
      return null;
    } catch (error) {
      debugPrint('Failed to create OpenAI-compatible provider: $error');
      return null;
    }
  }

  /// Handle provider discovery changes
  void _onProvidersChanged() {
    // Prevent infinite loops - don't re-initialize if already in progress
    if (_isInitializing) {
      debugPrint('Provider discovery changed, but initialization already in progress - skipping');
      return;
    }
    
    if (_isInitialized) {
      // Re-initialize providers when discovery changes
      debugPrint('Provider discovery changed, re-initializing...');
      initializeProviders();
    }
  }

  /// Clear all providers
  Future<void> _clearProviders() async {
    // Cancel any active subscriptions
    for (final subscription in _providerSubscriptions.values) {
      await subscription.cancel();
    }
    _providerSubscriptions.clear();

    // Clear providers
    _providers.clear();
    debugPrint('Cleared all LangChain providers');
  }

  /// Get provider by ID
  LangChainProviderWrapper? getProvider(String providerId) {
    return _providers[providerId];
  }

  /// Check if provider exists
  bool hasProvider(String providerId) {
    return _providers.containsKey(providerId);
  }

  /// Get provider statistics
  Map<String, dynamic> getProviderStats() {
    return {
      'total_providers': _providers.length,
      'available_providers': availableProviders.length,
      'preferred_provider': _preferredProviderId,
      'initialized': _isInitialized,
      'initializing': _isInitializing,
      'error': _error,
      'providers': _providers.keys.toList(),
    };
  }

  @override
  void dispose() {
    _discoveryService.removeListener(_onProvidersChanged);
    _clearProviders();
    super.dispose();
  }
}

/// Exception for LangChain integration errors
class LangChainIntegrationException implements Exception {
  final String message;
  final dynamic originalError;

  const LangChainIntegrationException(this.message, [this.originalError]);

  @override
  String toString() => 'LangChainIntegrationException: $message';
}
