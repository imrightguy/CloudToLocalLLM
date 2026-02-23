---
name: provider-setup
description: Add new LLM providers with adapter templates, auto-discovery integration, and rate limit tier configuration for the multi-provider router system
user-invocable: true
---

# LLM Provider Setup

Add new LLM providers to CloudToLocalLLM's multi-provider router with adapter templates, auto-discovery integration, and rate limit tier configuration.

## Context

CloudToLocalLLM supports multiple local and cloud LLM providers through a unified router server (port 1337):

### Local Providers
- **OpenClaw Gateway** - Primary local provider (localhost:18789)
- **LM Studio** - Alternative local provider (localhost:1234)
- **Ollama** - Alternative local provider (localhost:11434)

### Cloud Providers
- **Zhipu AI** (GLM models) - zhipu_adapter.dart
- **Google Gemini** - google_adapter.dart
- **Moonshot AI** - moonshot_adapter.dart

### Architecture
```
Router Server (port 1337)
    ↓
Provider Adapters (lib/services/providers/)
    ↓
LLMProviderManager (orchestrates selection)
    ↓
Rate Limit Manager (tracks concurrent requests)
    ↓
Model Tiers (critical/high/medium/unlimited capacity)
```

## Quick Start

### List Available Models
```bash
curl http://localhost:1337/v1/models
```

### Test Chat Completion
```bash
curl http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Health Check
```bash
curl http://localhost:1337/health
```

## Templates

### Provider Adapter Template
Location: `templates/provider_adapter.dart`

```dart
import 'package:cloudtolocalllm/services/providers/provider_adapter.dart';
import 'package:http/http.dart' as http;

/// [ProviderName] Adapter
///
/// Implements LLMProviderAdapter for [ProviderName] API
class [ProviderName]Adapter implements LLMProviderAdapter {
  final String apiKey;
  final String baseUrl;

  [ProviderName]Adapter({
    required this.apiKey,
    this.baseUrl = 'https://api.[provider].com/v1',
  });

  @override
  String get providerName => '[provider_name]';

  @override
  String get providerType => ProviderType.cloud;

  @override
  Future<String> transformRequest(Map<String, dynamic> request) async {
    // Transform OpenAI-format request to provider-specific format
    final messages = request['messages'] as List;

    return {
      'model': request['model'],
      'prompt': _formatPrompt(messages),
      'temperature': request['temperature'] ?? 0.7,
      'max_tokens': request['max_tokens'] ?? 1024,
      'stream': request['stream'] ?? false,
    };
  }

  @override
  Future<String> handleResponse(String response) async {
    // Transform provider response back to OpenAI format
    final data = jsonDecode(response);

    return {
      'id': data['id'] ?? generateId(),
      'object': 'chat.completion',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': data['model'],
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': data['text'],
          },
          'finish_reason': data['finish_reason'] ?? 'stop',
        }
      ],
      'usage': {
        'prompt_tokens': data['prompt_tokens'] ?? 0,
        'completion_tokens': data['completion_tokens'] ?? 0,
        'total_tokens': data['total_tokens'] ?? 0,
      },
    };
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  String _formatPrompt(List messages) {
    // Format messages for provider-specific prompt format
    return messages
        .map((m) => '${m['role']}: ${m['content']}')
        .join('\n');
  }

  String generateId() {
    return 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}';
  }
}
```

### Model Tier Configuration
Location: `templates/model_tiers.dart`

```dart
import 'package:cloudtolocalllm/services/model_tiers.dart';

/// Add [ProviderName] models to tier configuration
///
/// Tiers define rate limit capacity:
/// - critical: 1 concurrent request
/// - high: 5 concurrent requests
/// - medium: 20 concurrent requests
/// - unlimited: no rate limiting
void register[ProviderName]Models() {
  // Critical tier models (expensive/slow)
  ModelTierDefinitions.register[
      '[ProviderName]'] = ModelTierDefinition(
    tier: ModelTier.critical,
    models: [
      '[provider]-model-1-large',  // Flagship model
      '[provider]-model-2-ultra',
    ],
  );

  // High tier models (production quality)
  ModelTierDefinitions.register['[ProviderName]'] = ModelTierDefinition(
    tier: ModelTier.high,
    models: [
      '[provider]-model-3',
      '[provider]-model-4-turbo',
    ],
  );

  // Medium tier models (fast/cost-effective)
  ModelTierDefinitions.register['[ProviderName]'] = ModelTierDefinition(
    tier: ModelTier.medium,
    models: [
      '[provider]-model-5-small',
      '[provider]-model-6-lite',
    ],
  );
}
```

## Integration Steps

### 1. Create Provider Adapter
```bash
# Create adapter file
touch lib/services/providers/[provider]_adapter.dart
```

Use the provider adapter template above, replacing:
- `[ProviderName]` with PascalCase name
- `[provider]` with lowercase identifier
- API-specific fields in `transformRequest` and `handleResponse`

### 2. Register Adapter in Dependency Injection
File: `lib/di/locator.dart`

```dart
// Add import
import 'package:cloudtolocalllm/services/providers/[provider]_adapter.dart';

// Register in setupAuthenticatedServices()
locator.registerFactory<[ProviderName]Adapter>(
  () => [ProviderName]Adapter(
    apiKey: locator<String>(instanceName: '[provider]_api_key'),
  ),
);
```

### 3. Add Auto-Discovery Rules (for local providers)
File: `lib/services/provider_discovery_service.dart`

```dart
Future<DiscoveredProvider?> _discover[ProviderName]() async {
  // Try default port
  final port = 1234; // Provider's default port
  final response = await http
      .get(Uri.parse('http://localhost:$port/api/tags'))
      .timeout(const Duration(seconds: 1));

  if (response.statusCode == 200) {
    return DiscoveredProvider(
      name: '[ProviderName]',
      baseUrl: 'http://localhost:$port',
      type: ProviderType.local,
      isAvailable: true,
      discoveredAt: DateTime.now(),
    );
  }
  return null;
}
```

### 4. Configure Model Tiers
File: `lib/services/model_tiers.dart`

Add provider's models to appropriate tier using the template above.

### 5. Add API Key Configuration (for cloud providers)
File: `config/.env.production`

```bash
# [ProviderName] API Configuration
[PROVIDER]_API_KEY=your_api_key_here
[PROVIDER]_BASE_URL=https://api.[provider].com/v1  # Optional
```

### 6. Test Provider Integration
```bash
# Restart router server
flutter run

# List models (should include new provider)
curl http://localhost:1337/v1/models | jq '.data[] | select(.id | startswith("[provider]"))'

# Test chat completion
curl http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "[provider]-model-1",
    "messages": [{"role": "user", "content": "Hello from [ProviderName]!"}]
  }'
```

## Checklist

### Adapter Implementation
- [ ] Implements `LLMProviderAdapter` interface
- [ ] Provider name follows snake_case convention
- [ ] `transformRequest` converts OpenAI format to provider format
- [ ] `handleResponse` converts provider response to OpenAI format
- [ ] `isAvailable` checks provider health
- [ ] API key configured in environment
- [ ] Error handling for rate limits and timeouts

### Auto-Discovery (local providers)
- [ ] Port scanner checks provider's default port
- [ ] Health check endpoint verified
- [ ] Returns `DiscoveredProvider` with correct type
- [ ] Tested with provider server running
- [ ] Tested with provider server stopped

### Model Tier Configuration
- [ ] All models assigned to appropriate tier
- [ ] Model names match provider's naming convention
- [ ] Tier reflects model's capacity/cost
- [ ] Rate limit manager configured for tier
- [ ] Fallback model configured (if applicable)

### Testing
- [ ] Unit tests for adapter logic
- [ ] Integration test with real provider
- [ ] Rate limit behavior verified
- [ ] Error scenarios tested (timeout, 500, etc.)
- [ ] Streaming responses work correctly

## Troubleshooting

### Provider Not Showing in Model List
```bash
# Check adapter is registered
grep -r "[ProviderName]Adapter" lib/di/

# Test adapter directly
flutter test test/services/providers/[provider]_adapter_test.dart

# Check router logs for errors
flutter run -d linux --verbose
```

### Rate Limiting Too Aggressive
```bash
# Check model tier assignment
curl http://localhost:1337/v1/models | \
  jq '.data[] | select(.id=="[provider]-model-1") | .tier'

# Verify RateLimitManager settings
grep -A 10 "class RateLimitManager" lib/services/
```

### Authentication Failures
```bash
# Verify API key is loaded
echo $[PROVIDER]_API_KEY

# Test API key directly
curl -H "Authorization: Bearer $[PROVIDER]_API_KEY" \
  https://api.[provider].com/v1/models
```

## Related Files
- Provider manager: `lib/services/llm_provider_manager.dart`
- Provider discovery: `lib/services/provider_discovery_service.dart`
- Model tiers: `lib/services/model_tiers.dart`
- Rate limit manager: `lib/services/rate_limit_manager.dart`
- Router server: `lib/services/router_server.dart`
- Existing adapters: `lib/services/providers/*.dart`
