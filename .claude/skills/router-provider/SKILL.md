---
name: router-provider
description: Add new LLM provider adapter to the Flutter router system with OpenAI-compatible interface
disable-model-invocation: true
---

Add a new LLM provider to the router system for {{provider_name}}.

Include:
- Create adapter in lib/services/providers/{{provider_slug}}_adapter.dart
- Implement LlmProvider interface with complete() and streamComplete() methods
- Register in RouterServer in lib/di/locator.dart
- Add models to ModelRegistry in lib/services/model_tiers.dart
- API key configuration via environment variable

Follow existing patterns in lib/services/providers/zhipu_adapter.dart

Adapter structure:
```dart
import '../providers/base_provider.dart';

class {{ProviderName}}Adapter extends LlmProvider {
  final String apiKey;

  {{ProviderName}}Adapter({required this.apiKey})
      : super(
          providerId: '{{provider_slug}}',
          baseUrl: 'https://api.{{provider_slug}}.com/v1',
        );

  @override
  Future<CompletionResponse> complete(CompletionRequest request) async {
    // 1. Transform request to provider-specific format
    // 2. Call provider API
    // 3. Transform response to OpenAI format
    // 4. Return CompletionResponse
  }

  @override
  Stream<String> streamComplete(CompletionRequest request) async* {
    // 1. Transform request
    // 2. Call streaming API
    // 3. Yield chunks
    // 4. Handle errors and reconnection
  }

  // Helper methods
  Map<String, dynamic> _transformRequest(CompletionRequest request) {
    // Convert OpenAI format to provider format
  }

  CompletionResponse _transformResponse(Map<String, dynamic> response) {
    // Convert provider format to OpenAI format
  }
}
```

Model tier registration in lib/services/model_tiers.dart:
```dart
// In ModelRegistry.models map
'{{model_id}}': ModelConfig(
  id: '{{model_id}}',
  provider: '{{provider_slug}}',
  contextWindow: {{context_window}},
  tier: {{tier_number}},  // 1=primary, 2=fast, 3=fallback
),
```

Router registration in lib/di/locator.dart:
```dart
// In RouterServer providers map
final routerServer = RouterServer(
  rateLimitManager: rateLimitManager,
  providers: {
    // ... existing providers
    '{{provider_slug}}': {{ProviderName}}Adapter(
      apiKey: const String.fromEnvironment('{{API_KEY_ENV_VAR}}'),
    ),
  },
);
```

Required environment variable:
- `{{API_KEY_ENV_VAR}}` - API key for the provider

Testing:
- Test with curl: `curl http://localhost:1337/v1/chat/completions -d '{"model":"{{model_id}}","messages":[{"role":"user","content":"test"}]}'`
- Verify rate limiting works correctly
- Test fallback behavior when limits are reached
