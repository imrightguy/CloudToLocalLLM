---
name: rate-limit-model
description: Add LLM model to rate limiting system with tier configuration
disable-model-invocation: true
---

Add a new LLM model to the rate limiting and tier system for {{model_name}}.

Include:
- Add model configuration to ModelRegistry in lib/services/model_tiers.dart
- Set appropriate tier level (1=primary, 2=fast, 3=fallback, 4=unlimited)
- Configure context window size
- Define capacity limits based on tier
- Create RateLimitManager entries if needed

Follow existing patterns in lib/services/model_tiers.dart

Add model to ModelRegistry (lib/services/model_tiers.dart):
```dart
// In ModelRegistry.models map
'{{model_id}}': ModelConfig(
  id: '{{model_id}}',
  provider: '{{provider_name}}',  // zhipu, google, moonshot, openai, anthropic
  contextWindow: {{context_window}},  // e.g., 128000, 200000, 1000000
  tier: {{tier}},  // 1=primary, 2=fast, 3=fallback
),
```

Tier guidelines:
- **Tier 1 (Primary)**: High-quality models for main use
  - Examples: claude-3-opus, gpt-4-turbo, gemini-1.5-pro
  - Context: 100K-1M tokens
  - Use for: Complex tasks, coding, reasoning

- **Tier 2 (Fast/Efficient)**: Quick models for simple tasks
  - Examples: claude-3-haiku, gpt-3.5-turbo, gemini-2.0-flash
  - Context: 16K-200K tokens
  - Use for: Quick queries, simple prompts

- **Tier 3 (Fallback)**: Backup models when T1/T2 rate-limited
  - Examples: gemini-3-flash, older models
  - Context: 32K-100K tokens
  - Use for: Emergency fallback, testing

- **Tier 4 (Unlimited)**: Free/low-cost models with no limits
  - Examples: Local models, free tier APIs
  - Context: Variable
  - Use for: Development, testing

Capacity configuration in RateLimitManager (lib/services/rate_limit_manager.dart):
```dart
// Rate limits per tier (adjust based on your API quota)
static const Map<int, ModelCapacityConfig> tierCapacity = {
  1: ModelCapacityConfig(
    maxConcurrent: 5,      // Max concurrent requests
    rpm: 60,                // Requests per minute
    tpm: 90000,             // Tokens per minute
    cooldown: Duration(seconds: 60),
  ),
  2: ModelCapacityConfig(
    maxConcurrent: 10,
    rpm: 100,
    tpm: 150000,
    cooldown: Duration(seconds: 30),
  ),
  3: ModelCapacityConfig(
    maxConcurrent: 20,
    rpm: 200,
    tpm: 300000,
    cooldown: Duration(seconds: 15),
  ),
  4: ModelCapacityConfig(
    maxConcurrent: 50,
    rpm: 500,
    tpm: 1000000,
    cooldown: Duration(seconds: 5),
  ),
};
```

Model fallback chain (same tier):
When a model hits rate limits, the router falls back to another model in the same tier:
```dart
// Models are tried in order within each tier
// Example Tier 1: claude-3-opus -> gpt-4-turbo -> gemini-1.5-pro
```

Database tracking (in lib/database/drift_local_brain.dart):
```dart
// ModelCapacity table tracks current usage
class ModelCapacity extends Table {
  TextColumn get modelId => text()();
  IntColumn get currentConcurrent => integer().withDefault(const Constant(0))();
  IntColumn get requestsThisMinute => integer().withDefault(const Constant(0))();
  IntColumn get tokensThisMinute => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastRequestTime => dateTime().nullable()();
  DateTimeColumn get windowStartTime => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {modelId};
}

// LlmRequests table tracks request history
class LlmRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get modelId => text()();
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  IntColumn get totalTokens => integer().nullable()();
  IntColumn get latencyMs => integer().nullable()();
  TextColumn get switchedFromModel => text().nullable()();  // If fallback occurred
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

Testing the model:
```bash
# List available models
curl http://localhost:1337/v1/models

# Test chat completion
curl http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "{{model_id}}",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Test streaming
curl http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "{{model_id}}",
    "messages": [{"role": "user", "content": "Count to 5"}],
    "stream": true
  }'

# Check response headers for rate limit info
curl -I http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"{{model_id}}","messages":[{"role":"user","content":"test"}]}'
```

Monitoring:
```bash
# View model capacity in database
flutter run lib/test_brain_ui.dart  # Opens database viewer

# Check router logs
# Look for: "Switching to fallback model" or "Rate limit hit"
```

Common model providers:
- **Zhipu AI**: glm-4, glm-4-flash (context: 128K-200K)
- **Google Gemini**: gemini-1.5-pro, gemini-2.0-flash (context: 1M)
- **OpenAI**: gpt-4-turbo, gpt-3.5-turbo (context: 128K-16K)
- **Anthropic**: claude-3-opus, claude-3-haiku (context: 200K)
- **Moonshot AI**: moonshot-v1, moonshot-v1-8k
- **Local**: openclaw-gateway, lm-studio (tier 4 - unlimited)
