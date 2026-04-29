import 'package:logging/logging.dart';

import '../models/provider_configuration.dart';
import '../services/providers/hermes_provider.dart';

final Logger _log = Logger('ProviderConfigurationManager');

/// Manages provider configurations for different LLM backends.
class ProviderConfigurationManager {
  final Map<String, ProviderConfiguration> _configurations = {};
  String? _preferredProviderId;

  bool isProviderConfigured(String providerId) =>
      _configurations.containsKey(providerId);

  Future<void> setConfiguration(ProviderConfiguration configuration) async {
    _configurations[configuration.providerId] = configuration;
  }

  String? get preferredProviderId => _preferredProviderId;

  Future<void> setPreferredProvider(String providerId) async {
    _preferredProviderId = providerId;
  }

  Future<List<dynamic>> getAllProviders() async =>
      _configurations.values.toList(growable: false);

  Future<void> saveProvider({
    required String name,
    required ProviderType type,
    required String url,
    required bool isLocal,
    bool isDefault = false,
    String? version,
  }) async {
    final providerId = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final configuration = OpenAICompatibleProviderConfiguration(
      providerId: providerId,
      baseUrl: url,
      port: Uri.tryParse(url)?.port == 0 ? 80 : (Uri.tryParse(url)?.port ?? 80),
      requiresAuth: !isLocal,
      customSettings: {
        'name': name,
        'type': type.toString(),
        'isLocal': isLocal,
        if (version != null) 'version': version,
      },
    );
    await setConfiguration(configuration);
    if (isDefault) {
      await setPreferredProvider(providerId);
    }
  }

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