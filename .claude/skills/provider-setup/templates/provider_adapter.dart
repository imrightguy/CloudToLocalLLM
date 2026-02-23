/// LLM Provider Adapter Template
///
/// Generic template for implementing new LLM provider adapters
/// that work with CloudToLocalLLM's multi-provider router system.
///
/// Usage:
/// 1. Replace [ProviderName] with actual provider name
/// 2. Implement transformRequest() for provider-specific request format
/// 3. Implement handleResponse() for provider-specific response format
/// 4. Configure model tiers in lib/services/model_tiers.dart
/// 5. Register adapter in lib/di/locator.dart
///
/// See: lib/services/providers/provider_adapter.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloudtolocalllm/services/providers/provider_adapter.dart';
import 'package:cloudtolocalllm/services/providers/provider_types.dart';

/// [ProviderName] Adapter
///
/// Implements LLMProviderAdapter for [ProviderName] API
/// Converts between OpenAI-compatible format and provider-specific format
class [ProviderName]Adapter implements LLMProviderAdapter {
  /// API key for authentication
  final String apiKey;

  /// Base URL for provider API
  final String baseUrl;

  /// Request timeout duration
  final Duration timeout;

  [ProviderName]Adapter({
    required this.apiKey,
    this.baseUrl = 'https://api.[provider].com/v1',
    this.timeout = const Duration(seconds: 30),
  });

  @override
  String get providerName => '[provider_name]';

  @override
  String get providerType => ProviderType.cloud;

  @override
  Future<Map<String, dynamic>> transformRequest(
    Map<String, dynamic> request,
  ) async {
    // Transform OpenAI-format request to provider-specific format
    final messages = request['messages'] as List<Map<String, dynamic>>;

    // Example transformation - adjust based on provider's API
    return {
      'model': request['model'],
      'prompt': _formatPrompt(messages),
      'temperature': request['temperature'] ?? 0.7,
      'max_tokens': request['max_tokens'] ?? 1024,
      'stream': request['stream'] ?? false,
      // Add provider-specific fields here
      // 'top_p': request['top_p'] ?? 1.0,
      // 'frequency_penalty': request['frequency_penalty'] ?? 0.0,
      // 'presence_penalty': request['presence_penalty'] ?? 0.0,
    };
  }

  @override
  Future<Map<String, dynamic>> handleResponse(
    String response,
  ) async {
    // Transform provider response back to OpenAI format
    final data = jsonDecode(response);

    // Example transformation - adjust based on provider's response
    return {
      'id': data['id'] ?? _generateId(),
      'object': 'chat.completion',
      'created': data['created'] ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': data['model'] ?? '',
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': data['text'] ?? data['completion'] ?? '',
          },
          'finish_reason': data['finish_reason'] ?? 'stop',
        }
      ],
      'usage': {
        'prompt_tokens': data['usage']?['prompt_tokens'] ?? 0,
        'completion_tokens': data['usage']?['completion_tokens'] ?? 0,
        'total_tokens': data['usage']?['total_tokens'] ?? 0,
      },
    };
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/models'),
            headers: _buildHeaders(),
          )
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, String> buildHeaders() {
    return _buildHeaders();
  }

  @override
  String constructEndpoint(String model, String action) {
    // Construct the appropriate API endpoint
    // Most providers use /chat/completions for chat
    return '$baseUrl/chat/completions';
  }

  @override
  Future<void> validateConfiguration() async {
    if (apiKey.isEmpty) {
      throw ConfigurationException('API key is required for $providerName');
    }

    if (!await isAvailable()) {
      throw ConfigurationException(
        'Provider $providerName is not available at $baseUrl',
      );
    }
  }

  // Private helper methods

  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      // Add provider-specific headers here
      // 'X-Provider-Header': 'value',
    };
  }

  String _formatPrompt(List<Map<String, dynamic>> messages) {
    // Format messages for provider-specific prompt format
    // Adjust based on how the provider expects conversations

    // Example: Simple concatenation
    final buffer = StringBuffer();

    for (final message in messages) {
      final role = message['role'] ?? 'user';
      final content = message['content'] ?? '';
      buffer.writeln('$role: $content');
    }

    return buffer.toString().trim();
  }

  String _generateId() {
    // Generate a unique chat completion ID
    return 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Provider-specific exception for configuration errors
class ConfigurationException implements Exception {
  final String message;
  ConfigurationException(this.message);

  @override
  String toString() => 'ConfigurationException: $message';
}

/// Example usage:
///
/// ```dart
/// final adapter = [ProviderName]Adapter(
///   apiKey: 'your-api-key',
///   baseUrl: 'https://api.[provider].com/v1',
/// );
///
/// // Validate configuration
/// await adapter.validateConfiguration();
///
/// // Transform request
/// final openAIRequest = {
///   'model': 'model-name',
///   'messages': [
///     {'role': 'user', 'content': 'Hello!'}
///   ],
///   'temperature': 0.7,
/// };
///
/// final providerRequest = await adapter.transformRequest(openAIRequest);
///
/// // Make HTTP request to provider
/// final response = await http.post(
///   Uri.parse(adapter.constructEndpoint('model-name', 'chat')),
///   headers: adapter.buildHeaders(),
///   body: jsonEncode(providerRequest),
/// );
///
/// // Handle response
/// final openAIResponse = await adapter.handleResponse(response.body);
/// ```
