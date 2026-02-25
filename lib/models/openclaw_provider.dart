/// OpenClaw Provider Model
/// Represents a cloud provider configured in OpenClaw Gateway

library;

/// OpenClaw cloud provider configuration
class OpenClawProvider {
  /// Provider identifier (e.g., "zhipu", "google", "moonshot")
  final String id;

  /// Display name for the provider
  final String displayName;

  /// Available models from this provider
  final List<OpenClawModel> models;

  const OpenClawProvider({
    required this.id,
    required this.displayName,
    required this.models,
  });

  /// Create from JSON configuration
  factory OpenClawProvider.fromJson(
      Map<String, dynamic> json, String providerId) {
    final models = <OpenClawModel>[];
    if (json.containsKey('models')) {
      final modelsList = json['models'] as List<dynamic>;
      for (final model in modelsList) {
        if (model is String) {
          models.add(OpenClawModel(
            id: model,
            name: model,
            providerId: providerId,
          ));
        }
      }
    }

    return OpenClawProvider(
      id: providerId,
      displayName: _getDisplayName(providerId),
      models: models,
    );
  }

  static String _getDisplayName(String providerId) {
    switch (providerId.toLowerCase()) {
      case 'zhipu':
        return 'Zhipu AI (GLM)';
      case 'google':
        return 'Google (Gemini)';
      case 'moonshot':
        return 'Moonshot (Kimi)';
      case 'openai':
        return 'OpenAI';
      case 'anthropic':
        return 'Anthropic (Claude)';
      case 'ollama':
        return 'Ollama (Local)';
      default:
        return providerId[0].toUpperCase() + providerId.substring(1);
    }
  }

  /// Get the default model for this provider
  OpenClawModel? get defaultModel {
    if (models.isEmpty) return null;
    // Prefer models with "pro" or "plus" in name, otherwise first
    final preferred = models
        .where((m) =>
            m.name.toLowerCase().contains('pro') ||
            m.name.toLowerCase().contains('plus'))
        .firstOrNull;
    return preferred ?? models.first;
  }

  /// Get model by ID
  OpenClawModel? getModel(String modelId) {
    for (final model in models) {
      if (model.id == modelId) return model;
    }
    return null;
  }
}

/// Represents a specific model from a provider
class OpenClawModel {
  /// Unique model identifier (e.g., "glm-4-plus")
  final String id;

  /// Display name for the model
  final String name;

  /// Provider that hosts this model
  final String providerId;

  const OpenClawModel({
    required this.id,
    required this.name,
    required this.providerId,
  });

  /// Get the full model ID in provider-name/model-id format
  String get fullModelId => '$providerId/$id';

  /// Get the short display name
  String get shortName {
    // Remove common prefixes and suffixes
    String short = id
        .replaceAll(RegExp(r'^.*?[-/]'), '') // Remove everything before - or /
        .replaceAll(RegExp(r'-preview$'), '')
        .replaceAll(RegExp(r'-turbo$'), '')
        .replaceAll(RegExp(r'-\d{8}$'), ''); // Remove date suffix
    return short;
  }
}

/// Provider configuration from OpenClaw Gateway
class OpenClawProviderConfig {
  /// All configured providers
  final Map<String, OpenClawProvider> providers;

  /// Currently active provider/model combination
  final String? primaryProvider;

  const OpenClawProviderConfig({
    required this.providers,
    this.primaryProvider,
  });

  /// Get the active model
  OpenClawModel? get activeModel {
    if (primaryProvider == null) return null;
    final parts = primaryProvider!.split('/');
    if (parts.length != 2) return null;

    final providerId = parts[0];
    final modelId = parts[1];

    final provider = providers[providerId];
    if (provider == null) return null;

    return provider.getModel(modelId);
  }

  /// Get active provider
  OpenClawProvider? get activeProvider {
    if (primaryProvider == null) return null;
    final parts = primaryProvider!.split('/');
    if (parts.isEmpty) return null;
    return providers[parts.first];
  }

  /// Create from OpenClaw config JSON
  factory OpenClawProviderConfig.fromJson(Map<String, dynamic> json) {
    final providersMap = <String, OpenClawProvider>{};

    if (json.containsKey('models') &&
        json['models'] is Map &&
        json['models']['providers'] is Map) {
      final providersJson = json['models']['providers'] as Map<String, dynamic>;
      providersJson.forEach((providerId, providerConfig) {
        if (providerConfig is Map) {
          try {
            final provider = OpenClawProvider.fromJson(
              providerConfig as Map<String, dynamic>,
              providerId,
            );
            providersMap[providerId] = provider;
          } catch (e) {
            // Skip invalid provider configs
          }
        }
      });
    }

    String? primary;
    if (json.containsKey('agents') &&
        json['agents'] is Map &&
        json['agents']['defaults'] is Map) {
      final defaults = json['agents']['defaults'] as Map<String, dynamic>;
      if (defaults['model'] is Map && defaults['model']['primary'] is String) {
        primary = defaults['model']['primary'] as String;
      }
    }

    return OpenClawProviderConfig(
      providers: providersMap,
      primaryProvider: primary,
    );
  }
}

/// Extension for adding firstOrNull to Iterable
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
