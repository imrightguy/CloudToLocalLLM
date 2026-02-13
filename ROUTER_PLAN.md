# CloudToLocalLLM - LLM Router Plan

## Overview
Flutter app becomes the single LLM provider for OpenClaw. Exposes OpenAI-compatible API, handles rate limits internally, auto-switches models when busy.

## Architecture

```
┌─────────────┐     HTTP/OpenAI     ┌──────────────────┐     HTTP      ┌─────────────┐
│  OpenClaw   │ ───────────────────→│  Flutter Router  │ ────────────→ │   Zhipu     │
│             │ ←───────────────────│  (Port 1337)     │ ←──────────── │   Google    │
└─────────────┘   + X-Actual-Model  │                  │               │   Moonshot  │
                                    │  ┌─────────────┐ │
                                    │  │ Drift/SQLite│ │
                                    │  │ ModelCapacity│ │
                                    │  │ LlmRequests │ │
                                    │  └─────────────┘ │
                                    └──────────────────┘
```

## Phase 1: Foundation (Day 1)

### 1.1 Database Schema (Drift)
**File:** `lib/database/drift_local_brain.dart`

**Tables:**
- `ModelCapacity` - Live rate limit tracking
- `LlmRequests` - Request history for analytics

**Fields:**
```dart
ModelCapacity:
  - modelId (PK): String
  - provider: String (zhipu/google/moonshot)
  - displayName: String
  - concurrentUsed: Int
  - concurrentLimit: Int
  - tpmUsed: Int (optional)
  - tpmLimit: Int (optional)
  - lastUpdated: DateTime
  - status: String (active/degraded/offline)

LlmRequests:
  - id (PK): Int
  - requestId: String (UUID)
  - modelId: String (FK)
  - requestedModel: String (what OpenClaw asked for)
  - actualModel: String (what we actually used)
  - status: String (pending/active/completed/failed)
  - promptTokens: Int
  - completionTokens: Int
  - startedAt: DateTime
  - completedAt: DateTime
  - errorMessage: String?
```

**Migration:** v3 - adds both tables, populates with known limits

### 1.2 Model Tier System
**File:** `lib/services/model_tiers.dart`

```dart
enum ModelTier {
  critical,    // 1 concurrent: GLM-4.7-Flash, GLM-5
  high,        // 3 concurrent: GLM-4.7, GLM-4.6
  medium,      // 10-15 concurrent: GLM-4.5, GLM-4-32B
  unlimited,   // 60+ concurrent: Gemini-3-Flash/Pro, GLM-4-Plus
}

Map<String, ModelConfig> modelConfigs = {
  'glm-4.7': ModelConfig(tier: Tier.high, provider: 'zhipu', fallback: 'glm-4-plus'),
  'gemini-3-flash': ModelConfig(tier: Tier.unlimited, provider: 'google', fallback: null),
  // ... etc
};
```

### 1.3 Provider Adapters
**Files:** 
- `lib/services/providers/zhipu_adapter.dart`
- `lib/services/providers/google_adapter.dart`
- `lib/services/providers/moonshot_adapter.dart`

**Interface:**
```dart
abstract class LlmProvider {
  String get name;
  Future<Stream<String>> streamCompletion(CompletionRequest request);
  Future<CompletionResponse> complete(CompletionRequest request);
}
```

Each adapter translates OpenAI format to provider-specific format.

## Phase 2: Router Core (Day 2)

### 2.1 Rate Limit Manager
**File:** `lib/services/rate_limit_manager.dart`

**Responsibilities:**
- Track concurrent usage per model
- Check availability before request
- Auto-switch logic
- Update usage on request start/end
- Parse rate limit headers from responses

**Key Methods:**
```dart
Future<bool> isAvailable(String modelId);
Future<String> getAvailableModel(String requestedModelId);
Future<void> startRequest(String modelId, String requestId);
Future<void> endRequest(String modelId, String requestId, {bool success});
Future<void> syncFromHeader(String modelId, int remaining);
```

### 2.2 HTTP Server
**File:** `lib/services/router_server.dart`

**Framework:** `shelf` + `shelf_router`

**Endpoints:**
```
GET  /v1/models              → List available models
POST /v1/chat/completions    → Main endpoint (streaming + non-streaming)
GET  /health                 → Health check
```

**Request Flow:**
1. Parse OpenAI-format request
2. Extract requested model
3. Check availability via RateLimitManager
4. If busy → get fallback model
5. Call appropriate provider adapter
6. Stream response back
7. Log actual model used

### 2.3 Request Lifecycle
```
1. Receive POST /v1/chat/completions
2. Generate requestId (UUID)
3. Insert into LlmRequests (status: pending)
4. Check ModelCapacity for requested model
5. IF available:
   - Update ModelCapacity (concurrentUsed++)
   - Update LlmRequests (status: active, actualModel = requested)
   - Call provider adapter
   - Stream response
   - On complete: concurrentUsed--, status: completed
6. IF busy:
   - Find fallback in same tier (or next tier up)
   - Update LlmRequests (actualModel = fallback)
   - Call provider adapter for fallback
   - Add X-Actual-Model header to response
   - Stream response
   - On complete: update counters
```

## Phase 3: Integration (Day 3)

### 3.1 OpenClaw Config
**File:** `~/.openclaw/openclaw.json`

```json
{
  "models": {
    "providers": {
      "cloudtolocalllm-router": {
        "baseUrl": "http://localhost:3000",
        "api": "openai",
        "models": [
          {"id": "glm-4.7", "name": "GLM-4.7"},
          {"id": "glm-4.7-flash", "name": "GLM-4.7 Flash"},
          {"id": "glm-4-plus", "name": "GLM-4 Plus"},
          {"id": "glm-5", "name": "GLM-5"},
          {"id": "gemini-3-flash", "name": "Gemini 3 Flash"},
          {"id": "gemini-3-pro", "name": "Gemini 3 Pro"},
          {"id": "kimi-k2.5", "name": "Kimi K2.5"},
          {"id": "kimi-k2-thinking", "name": "Kimi K2 Thinking"}
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "cloudtolocalllm-router/glm-4.7",
        "fallbacks": [
          "cloudtolocalllm-router/glm-4-plus",
          "cloudtolocalllm-router/gemini-3-flash"
        ]
      }
    }
  }
}
```

### 3.2 Flutter UI Components
**Files:**
- `lib/widgets/router_status_card.dart` - Show server status
- `lib/widgets/capacity_gauge.dart` - Live model usage bars
- `lib/screens/router_dashboard.dart` - Full dashboard

**Features:**
- Toggle server on/off
- View active requests
- See capacity bars for each model
- Recent request log
- Error display

### 3.3 Settings Integration
**File:** `lib/screens/settings/router_settings.dart`

**Options:**
- Port number (default: 3000)
- Auto-start server on app launch
- API keys for each provider
- Fallback behavior (auto-switch vs queue vs reject)
- Log retention

## Phase 4: Polish (Day 4+)

### 4.1 Error Handling
- Provider timeout → Mark degraded, auto-fallback
- Provider 429 → Update capacity, auto-fallback  
- Provider 5xx → Mark offline, auto-fallback
- Network error → Retry with backoff

### 4.2 Analytics
- Request volume per model
- Fallback frequency
- Average response time per provider
- Error rate tracking

### 4.3 Advanced Features
- Request queue (optional, if user wants)
- Token counting before request (estimate cost)
- Provider health checks (ping every 30s)
- Circuit breaker (disable provider after N errors)

## File Structure

```
lib/
├── database/
│   ├── drift_local_brain.dart      (MODIFY - add tables)
│   └── ...
├── services/
│   ├── router_server.dart          (NEW - HTTP server)
│   ├── rate_limit_manager.dart     (NEW - capacity tracking)
│   ├── model_tiers.dart            (NEW - tier definitions)
│   └── providers/
│       ├── base_provider.dart      (NEW - interface)
│       ├── zhipu_adapter.dart      (NEW)
│       ├── google_adapter.dart     (NEW)
│       └── moonshot_adapter.dart   (NEW)
├── widgets/
│   ├── router_status_card.dart     (NEW)
│   └── capacity_gauge.dart         (NEW)
├── screens/
│   ├── router_dashboard.dart       (NEW)
│   └── settings/
│       └── router_settings.dart    (NEW)
└── models/
    └── router_models.dart          (NEW - data classes)
```

## Dependencies to Add

```yaml
dependencies:
  shelf: ^1.4.1
  shelf_router: ^1.1.4
  http: ^1.2.0
  uuid: ^4.3.3
  
dev_dependencies:
  # Already have drift, build_runner
```

## Testing Strategy

1. **Unit Tests:** RateLimitManager logic, tier fallback
2. **Integration Tests:** Mock provider responses
3. **Manual Tests:** Connect real OpenClaw, verify streaming

## Open Questions

1. **Streaming:** SSE or WebSocket? SSE is simpler, WebSocket is more flexible
2. **Port:** 1337 (leet)
3. **Auth:** Skip for local, or simple token?
4. **Queue:** Implement or skip for MVP?

## Success Criteria

- [ ] OpenClaw can connect and list models
- [ ] OpenClaw can send request, get response
- [ ] When GLM-4.7 busy, auto-switches to GLM-4-Plus
- [ ] X-Actual-Model header present
- [ ] UI shows live capacity
- [ ] Request history logged in Drift
