# CloudToLocalLLM System Architecture

CloudToLocalLLM is a Flutter desktop/web application with optional Node.js backend services. The product is organized around five pillars: Chat, OpenClaw Gateway, Evolving Avatar, Desktop Control, and Vision.

Core functionality is local-first. Cloud services add authentication, sync, relay, admin, and deployment capabilities, but should not be required for the local desktop path.

## Technology Stack

| Layer | Current implementation |
| --- | --- |
| Flutter app | `pubspec.yaml`, Dart `>=3.5.0 <4.0.0`, package `cloudtolocalllm` |
| Shared Flutter package | `lib/shared/pubspec.yaml`, Dart `>=3.9.0 <4.0.0` |
| Local database | Drift/SQLite in `lib/database/drift_local_brain.dart` |
| Embedded router | Shelf server in `lib/services/router_server.dart`, default port `1337` |
| API backend | Express 5 ESM in `services/api-backend/`, Node `>=22 <25`, default port `8080` |
| Streaming proxy | ESM service in `services/streaming-proxy/`, Node `>=22 <25`, default port `3001` |
| Tailscale relay | ESM service in `services/tailscale-relay/`, default port `3002` |
| Auth backend | CommonJS Express 5 app in `backend/auth/`, default port `3000` |

## Flutter Structure

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry point |
| `lib/bootstrap/` | Startup/bootstrap support |
| `lib/di/locator.dart` | GetIt service registration and two-phase DI |
| `lib/database/` | Drift database and platform connections |
| `lib/services/` | Service layer |
| `lib/services/providers/` | Router provider adapters |
| `lib/services/avatar/` | Personality, evolution, memory, avatar state |
| `lib/services/openclaw_manager/` | Gateway control |
| `lib/services/hermes_manager/` | Hermes gateway and streaming management |
| `lib/services/desktop_control/` | Clipboard and desktop window control |
| `lib/services/vision/` | Region capture, camera capture, OCR, vision orchestration |
| `lib/screens/` | App screens |
| `lib/widgets/` | Shared UI widgets |

## Dependency Injection

`lib/di/locator.dart` owns service registration.

1. `setupCoreServices()` registers pre-auth services: settings, session/auth support, local brain, router, provider discovery, platform detection, setup wizard, and tier services.
2. `setupAuthenticatedServices()` calls core setup first, then registers auth-dependent services: tunnel, streaming proxy, LLM provider manager, LangChain, gateway control, agent lifecycle, admin, desktop control, vision, and popout services.

Use `di.serviceLocator<T>()` or `serviceLocator.get<T>()` for registered services. Do not instantiate long-lived services directly unless the file already follows that pattern for a local helper.

## Pillar Services

### Chat

| Service | File |
| --- | --- |
| `StreamingChatService` | `lib/services/streaming_chat_service.dart` |
| `ConversationStorageService` | `lib/services/conversation_storage_service.dart` |
| `LocalConversationStorage` | `lib/services/local_conversation_storage.dart` |

### OpenClaw Gateway

| Service | File |
| --- | --- |
| `ConnectionManagerService` | `lib/services/connection_manager_service.dart` |
| `AgentStatusService` | `lib/services/agent_status_service.dart` |
| `AgentLifecycleService` | `lib/services/agent_lifecycle_service.dart` |
| `GatewayControlService` | `lib/services/openclaw_manager/gateway_control_service.dart` |

Provider discovery scans local providers including OpenClaw Gateway on `localhost:18789`, LM Studio on `localhost:1234`, and Ollama on `localhost:11434`.

### Avatar

| Service | File |
| --- | --- |
| `AvatarStateService` | `lib/services/avatar/avatar_state_service.dart` |
| `PersonalityEngine` | `lib/services/avatar/personality_engine.dart` |
| `EvolutionTracker` | `lib/services/avatar/evolution_tracker.dart` |
| `MemoryService` | `lib/services/avatar/memory_service.dart` |
| `MarkdownSyncService` | `lib/services/avatar/markdown_sync_service.dart` |

### Desktop Control

| Service | File |
| --- | --- |
| `GuiAutomationService` | `lib/services/gui_automation_service.dart` |
| `SystemControlService` | `lib/services/system_control_service.dart` |
| `ClipboardService` | `lib/services/desktop_control/clipboard_service.dart` |
| `WindowManagerService` | `lib/services/desktop_control/window_manager_service.dart` |

### Vision

| Service | File |
| --- | --- |
| `VisionService` | `lib/services/vision/vision_service.dart` |
| `RegionCaptureService` | `lib/services/vision/region_capture_service.dart` |
| `CameraCaptureService` | `lib/services/vision/camera_capture_service.dart` |
| `OcrEngineService` | `lib/services/vision/ocr_engine_service.dart` |

## Embedded Router

The Flutter app embeds an OpenAI-compatible HTTP router:

- Implementation: `lib/services/router_server.dart`
- Default port: `1337`
- Health: `GET /health`
- Models: `GET /v1/models`
- Chat: `POST /v1/chat/completions`
- Avatar state: `GET /avatar/state`
- Avatar traits: `POST /avatar/traits`
- Avatar evolution request: `POST /avatar/evolution/request`

Current provider adapter files:

| Adapter | File |
| --- | --- |
| Base models/interface | `lib/services/providers/base_provider.dart` |
| Zhipu | `lib/services/providers/zhipu_adapter.dart` |
| Google | `lib/services/providers/google_adapter.dart` |
| Moonshot | `lib/services/providers/moonshot_adapter.dart` |
| Hermes | `lib/services/providers/hermes_adapter.dart` |

Provider configuration and discovery for local services are handled separately by `ProviderConfigurationManager`, `ProviderDiscoveryService`, and `LLMProviderManager`.

## Data Storage

| Store | Use |
| --- | --- |
| Drift/SQLite | Local brain, conversations, avatar state, memories, rate-limit data |
| IndexedDB/web storage | Web-safe client storage paths |
| PostgreSQL | Optional backend persistence for authenticated cloud features |
| Markdown sync | Avatar/personality backup and OpenClaw skill integration |

After changing Drift schema or queries, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Backend Services

| Service | Directory | Notes |
| --- | --- | --- |
| API backend | `services/api-backend/` | Express 5, Auth0 JWT, PostgreSQL, admin routes, tunnel/proxy APIs |
| Streaming proxy | `services/streaming-proxy/` | WebSocket/HTTP proxy container with TypeScript modules under `src/` |
| Tailscale relay | `services/tailscale-relay/` | Relay service using Express 4 |
| Auth backend | `backend/auth/` | Lightweight CommonJS Auth0 JWT validation |
| SDK | `services/sdk/` | TypeScript SDK published from `dist/` |
| OpenClaw skills | `services/openclaw-skills/cloudtolocallm/` | Avatar personality/evolution skill package |

## Platform Boundaries

The app uses conditional imports for web/native splits. Do not import `dart:io` in shared code.

Examples in the repo use:

- `dart.library.io`
- `dart.library.html`
- `dart.library.js_interop`

Match nearby file patterns when adding platform-specific code.

## Related Documentation

- [Documentation Hub](../README.md)
- [Avatar System](AVATAR_SYSTEM.md)
- [Desktop Control](DESKTOP_CONTROL.md)
- [Vision System](VISION_SYSTEM.md)
- [Tunnel System](TUNNEL_SYSTEM.md)
- [Service Lifecycle](service_lifecycle.md)
