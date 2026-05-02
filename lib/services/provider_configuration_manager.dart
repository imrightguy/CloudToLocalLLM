import 'package:logging/logging.dart';

import '../models/provider_configuration.dart';
import '../services/providers/hermes_provider.dart';

final Logger _log = Logger('ProviderConfigurationManager');

/// Manages provider configurations for different LLM backends.
class ProviderConfigurationManager {
  final Map<String, ProviderConfiguration> _configurations = {};
  String? _activeRuntimeProviderId;
  String? _preferredSupportProviderId;

  bool isProviderConfigured(String providerId) =>
      _configurations.containsKey(providerId);

  Future<void> setConfiguration(ProviderConfiguration configuration) async {
    _configurations[configuration.providerId] = configuration;
  }

  /// Backward-compatible alias for the main runtime selection.
  String? get preferredProviderId => _activeRuntimeProviderId;
  String? get activeRuntimeProviderId => _activeRuntimeProviderId;
  String? get preferredSupportProviderId => _preferredSupportProviderId;

  Future<void> setPreferredProvider(String providerId) async {
    await setActiveRuntimeProvider(providerId);
  }

  Future<void> setActiveRuntimeProvider(String providerId) async {
    final configuration = _configurations[providerId];
    if (configuration == null) {
      throw ArgumentError('Unknown provider configuration: $providerId');
    }

    if (!_isAgentRuntimeConfiguration(configuration)) {
      throw ArgumentError(
        'Support model providers cannot be selected as the main agent runtime.',
      );
    }

    _activeRuntimeProviderId = providerId;
  }

  Future<void> setPreferredSupportProvider(String providerId) async {
    final configuration = _configurations[providerId];
    if (configuration == null) {
      throw ArgumentError('Unknown provider configuration: $providerId');
    }

    if (!_isSupportModelProviderConfiguration(configuration)) {
      throw ArgumentError(
        'Agent runtimes cannot be selected as support model providers.',
      );
    }

    _preferredSupportProviderId = providerId;
  }

  Future<List<dynamic>> getAllProviders() async =>
      _configurations.values.toList(growable: false);

  Future<List<ProviderConfiguration>> getAllAgentRuntimes() async =>
      _configurations.values
          .where(_isAgentRuntimeConfiguration)
          .toList(growable: false);

  Future<List<ProviderConfiguration>> getAllSupportModelProviders() async =>
      _configurations.values
          .where(_isSupportModelProviderConfiguration)
          .toList(growable: false);

  Future<void> saveProvider({
    required String name,
    required ProviderType type,
    required String url,
    required bool isLocal,
    bool isDefault = false,
    String? version,
    ProviderRole? role,
  }) async {
    final providerId =
        name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final effectiveRole = role ?? type.defaultRole;
    final configuration = OpenAICompatibleProviderConfiguration(
      providerId: providerId,
      baseUrl: url,
      port: Uri.tryParse(url)?.port == 0 ? 80 : (Uri.tryParse(url)?.port ?? 80),
      requiresAuth: !isLocal,
      customSettings: {
        'name': name,
        'type': type.name,
        'role': effectiveRole.name,
        'isLocal': isLocal,
        if (version != null) 'version': version,
      },
    );
    await setConfiguration(configuration);
    if (isDefault) {
      if (effectiveRole == ProviderRole.agentRuntime) {
        await setActiveRuntimeProvider(providerId);
      } else {
        throw ArgumentError(
          '$name is a support model provider and cannot be the main runtime.',
        );
      }
    }
  }

  bool _isAgentRuntimeConfiguration(ProviderConfiguration configuration) {
    final role = configuration.customSettings['role'];
    if (role == ProviderRole.agentRuntime.name) {
      return true;
    }
    if (role == ProviderRole.supportModelProvider.name) {
      return false;
    }

    final type = configuration.customSettings['type']?.toString();
    if (type != null) {
      final providerType = ProviderType.values.firstWhere(
        (value) => value.name == type || value.toString() == type,
        orElse: () => ProviderType.openAICompatible,
      );
      return providerType.isAgentRuntime;
    }

    return configuration.providerType == 'hermes';
  }

  bool _isSupportModelProviderConfiguration(
    ProviderConfiguration configuration,
  ) =>
      !_isAgentRuntimeConfiguration(configuration);

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
