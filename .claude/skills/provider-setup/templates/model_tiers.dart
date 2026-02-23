/// Model Tier Configuration Template
///
/// Add new provider models to CloudToLocalLLM's rate limiting system
///
/// Tiers define concurrent request capacity:
/// - critical: 1 request (expensive/slow models)
/// - high: 5 requests (production models)
/// - medium: 20 requests (fast/cost-effective models)
/// - unlimited: no limit (internal/local models)

import 'package:cloudtolocalllm/services/model_tiers.dart';

/// Register [ProviderName] models in tier configuration
///
/// Call this function during app initialization to register
/// the provider's models with appropriate rate limit tiers.
void register[ProviderName]Models() {
  // Critical Tier - Expensive or slow models
  // Limited to 1 concurrent request
  ModelTierDefinitions.register['[provider]'] = ModelTierDefinition(
    tier: ModelTier.critical,
    models: [
      '[provider]-flagship',        // Best quality, slow
      '[provider]-ultra',           // Maximum capability
      '[provider]-research-preview', // Experimental model
    ],
    metadata: {
      'reason': 'High cost and latency models',
      'fallback': '[provider]-standard',  // Fallback when rate limited
    },
  );

  // High Tier - Production quality models
  // Limited to 5 concurrent requests
  ModelTierDefinitions.register['[provider]'] = ModelTierDefinition(
    tier: ModelTier.high,
    models: [
      '[provider]-standard',       // Standard production model
      '[provider]-turbo',          // Fast variant
      '[provider]-pro',            // Professional tier
    ],
    metadata: {
      'reason': 'Production models with good quality/speed balance',
      'fallback': '[provider]-lite',
    },
  );

  // Medium Tier - Fast, cost-effective models
  // Limited to 20 concurrent requests
  ModelTierDefinitions.register['[provider]'] = ModelTierDefinition(
    tier: ModelTier.medium,
    models: [
      '[provider]-lite',           // Lightweight model
      '[provider]-small',          // Small variant
      '[provider]-fast',           // Optimized for speed
      '[provider]-mini',           // Minimal model
    ],
    metadata: {
      'reason': 'Fast, cost-effective models for high-volume usage',
      'fallback': null,  // No fallback for medium tier
    },
  );

  // Unlimited Tier - Local or internal models
  // No rate limiting
  ModelTierDefinitions.register['[provider]'] = ModelTierDefinition(
    tier: ModelTier.unlimited,
    models: [
      '[provider]-local',          // Local hosted model
      '[provider]-internal',       // Internal deployment
    ],
    metadata: {
      'reason': 'Local/internal models with no external rate limits',
      'fallback': null,
    },
  );
}

/// Example: Model-specific rate limit overrides
///
/// Some models may need custom rate limits regardless of tier
void configure[ProviderName]RateLimitOverrides() {
  RateLimitManager.setOverride('[provider]-flagship', concurrentLimit: 1);
  RateLimitManager.setOverride('[provider]-standard', concurrentLimit: 10);
  RateLimitManager.setOverride('[provider]-lite', concurrentLimit: 50);
}

/// Example: Provider-specific rate limit strategy
///
/// Different providers may have different rate limit behaviors
class [ProviderName]RateLimitStrategy implements RateLimitStrategy {
  @override
  int getConcurrentLimit(String model) {
    // Provider-specific logic for rate limiting
    if (model.contains('turbo')) {
      return 10;  // Turbo models can handle more concurrency
    }
    if (model.contains('ultra')) {
      return 1;   // Ultra models are single-threaded
    }
    return 5;     // Default
  }

  @override
  Duration getRetryDelay(String model, int attemptNumber) {
    // Exponential backoff for rate limit errors
    return Duration(seconds: attemptNumber * 2);
  }

  @override
  bool shouldRetry(String model, int statusCode) {
    // Retry on specific status codes
    return statusCode == 429 ||  // Too Many Requests
           statusCode == 503 ||  // Service Unavailable
           statusCode == 504;    // Gateway Timeout
  }
}

/// Usage Example:
///
/// ```dart
/// // During app initialization
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Register provider models
///   register[ProviderName]Models();
///
///   // Configure rate limit overrides
///   configure[ProviderName]RateLimitOverrides();
///
///   // Set custom rate limit strategy
///   RateLimitManager.setStrategy('[provider]',
///       [ProviderName]RateLimitStrategy());
///
///   runApp(MyApp());
/// }
/// ```
