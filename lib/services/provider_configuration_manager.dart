import 'package:logging/logging.dart';

import '../services/providers/hermes_provider.dart';

final Logger _log = Logger('ProviderConfigurationManager');

/// Manages provider configurations for different LLM backends.
class ProviderConfigurationManager {
  /// Get the Hermes provider instance.
  ///
  /// [baseUrl] is the base URL for hermes-agent API.
  /// [apiKey] is the API key for authentication.
  HermesProvider getHermesProvider({
    String baseUrl = 'http://localhost:1337',
    required String apiKey,
  }) {
    _log.info('Creating HermesProvider: $baseUrl');
    return HermesProvider(
      baseUrl: baseUrl,
      apiKey: apiKey,
    );
  }

  /// Get the list of available models from Hermes.
  ///
  /// [baseUrl] is the base URL for hermes-agent API.
  /// [apiKey] is the API key for authentication.
  Future<List<Map<String, dynamic>>> getHermesModels({
    String baseUrl = 'http://localhost:1337',
    required String apiKey,
  }) async {
    final provider = HermesProvider(baseUrl: baseUrl, apiKey: apiKey);
    try {
      final models = await provider.getModels();
      _log.info('Hermes models: ${models.length}');
      return models;
    } catch (e, st) {
      _log.severe('Failed to get Hermes models', e, st);
      rethrow;
    } finally {
      provider.close();
    }
  }
}