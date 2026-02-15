/// Model registry for LLM providers with tier-based fallback chains
library;

/// Model configuration
class ModelConfig {
  final String id;
  final String provider;
  final int contextWindow;
  final int tier;

  const ModelConfig({
    required this.id,
    required this.provider,
    required this.contextWindow,
    required this.tier,
  });
}

/// Registry of all available models with their configurations
class ModelRegistry {
  static const Map<String, ModelConfig> models = {
    // Tier 1 - Primary models
    'claude-3-opus': ModelConfig(
      id: 'claude-3-opus',
      provider: 'anthropic',
      contextWindow: 200000,
      tier: 1,
    ),
    'claude-3-sonnet': ModelConfig(
      id: 'claude-3-sonnet',
      provider: 'anthropic',
      contextWindow: 200000,
      tier: 1,
    ),
    'gpt-4-turbo': ModelConfig(
      id: 'gpt-4-turbo',
      provider: 'openai',
      contextWindow: 128000,
      tier: 1,
    ),
    'gemini-1.5-pro': ModelConfig(
      id: 'gemini-1.5-pro',
      provider: 'google',
      contextWindow: 1000000,
      tier: 1,
    ),

    // Tier 2 - Fast/efficient models
    'claude-3-haiku': ModelConfig(
      id: 'claude-3-haiku',
      provider: 'anthropic',
      contextWindow: 200000,
      tier: 2,
    ),
    'gpt-3.5-turbo': ModelConfig(
      id: 'gpt-3.5-turbo',
      provider: 'openai',
      contextWindow: 16384,
      tier: 2,
    ),
    'gemini-2.0-flash': ModelConfig(
      id: 'gemini-2.0-flash',
      provider: 'google',
      contextWindow: 1000000,
      tier: 2,
    ),
    'glm-4-flash': ModelConfig(
      id: 'glm-4-flash',
      provider: 'zhipu',
      contextWindow: 128000,
      tier: 2,
    ),

    // Tier 3 - Fallback models
    'gemini-3-flash': ModelConfig(
      id: 'gemini-3-flash',
      provider: 'google',
      contextWindow: 1000000,
      tier: 3,
    ),
  };

  /// Get model config by ID
  static ModelConfig get(String modelId) {
    return models[modelId] ??
        const ModelConfig(
          id: 'unknown',
          provider: 'unknown',
          contextWindow: 4096,
          tier: 3,
        );
  }

  /// Get fallback chain for a model (returns model IDs in order of preference)
  static List<String> getFallbackChain(String requestedModelId) {
    final config = get(requestedModelId);
    final chain = <String>[requestedModelId];

    // Add tier-based fallbacks
    if (config.tier == 1) {
      // Tier 1 falls back to tier 2 models
      chain.addAll(['gemini-2.0-flash', 'glm-4-flash']);
    }

    // Always add final fallback
    if (!chain.contains('gemini-3-flash')) {
      chain.add('gemini-3-flash');
    }

    return chain;
  }

  /// Get all models by provider
  static List<ModelConfig> getByProvider(String provider) {
    return models.values.where((m) => m.provider == provider).toList();
  }

  /// Get all models by tier
  static List<ModelConfig> getByTier(int tier) {
    return models.values.where((m) => m.tier == tier).toList();
  }
}
