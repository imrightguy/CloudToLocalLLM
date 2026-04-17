import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

final Logger _log = Logger('HermesProvider');

/// Adapter for hermes-agent provider.
///
/// This provides a standard interface for interacting with hermes-agent's
/// chat completions API.
class HermesProvider {
  final String _baseUrl;
  final String _apiKey;
  final http.Client _client;

  /// Create a new Hermes provider.
  ///
  /// [baseUrl] is the base URL for hermes-agent API (e.g., 'http://localhost:1337').
  /// [apiKey] is the API key for authentication.
  HermesProvider({
    String baseUrl = 'http://localhost:1337',
    required String apiKey,
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _client = http.Client();

  /// Make a chat completion request.
  ///
  /// [messages] is a list of message objects.
  /// [model] is the model ID to use.
  /// [temperature] is the temperature (default 0.7).
  /// [maxTokens] is the maximum tokens to generate (default null).
  ///
  /// Returns a map representing the API response.
  Future<Map<String, dynamic>> chatCompletion(
    List<Map<String, dynamic>> messages, {
    String? model,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    final endpoint = '$_baseUrl/v1/chat/completions';
    final body = {
      'model': model ?? 'hermes/model',
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    _log.fine('HermesProvider request: $body');

    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            body: jsonEncode(body),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _log.fine('HermesProvider response: ${data['choices']}');
        return data;
      } else {
        final error = jsonDecode(response.body)['error'] ?? response.body;
        _log.severe('HermesProvider error: $error');
        throw Exception('HermesProvider error: $error');
      }
    } catch (e, st) {
      _log.severe('HermesProvider request failed', e, st);
      throw Exception('HermesProvider request failed: $e');
    }
  }

  /// Get the list of available models.
  Future<List<Map<String, dynamic>>> getModels() async {
    final endpoint = '$_baseUrl/v1/models';

    try {
      final response = await _client
          .get(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['models'] as List).cast<Map<String, dynamic>>();
      } else {
        final error = jsonDecode(response.body)['error'] ?? response.body;
        _log.severe('HermesProvider models error: $error');
        throw Exception('HermesProvider models error: $error');
      }
    } catch (e, st) {
      _log.severe('HermesProvider models request failed', e, st);
      throw Exception('HermesProvider models request failed: $e');
    }
  }

  /// Close the HTTP client.
  void close() {
    _client.close();
  }
}