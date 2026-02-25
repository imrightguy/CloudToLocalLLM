# CloudToLocalLLM System Architecture

**OpenClaw Agent Manager** — A privacy-first desktop AI companion.

---

## Overview

CloudToLocalLLM is a Flutter-based desktop application (Windows, Linux, Web) that manages the OpenClaw Gateway as a local AI engine. The application is organized around **Five Core Pillars**: Chat, OpenClaw Gateway Management, Evolving Avatar, Desktop Control, and Vision.

**Key Architectural Principles:**

- **Privacy-First**: All processing runs locally via OpenClaw Gateway
- **Local-First**: Zero cloud dependencies for core functionality
- **Optional Cloud**: Cloud features (Auth0, tunneling) are opt-in only
- **Cross-Platform**: Single Flutter codebase for desktop and web
- **Service-Oriented**: Modular services with dependency injection

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter 3.5+ | Cross-platform UI (Windows, Linux, Web) |
| **AI Engine** | OpenClaw Gateway | Local LLM and vision processing (localhost:18789) |
| **Local Database** | Drift (SQLite) | Conversation storage, configuration |
| **Backend (Optional)** | Node.js 22+ | Cloud relay, tunneling (optional) |
| **Authentication (Optional)** | Auth0 | Cloud account sync (optional) |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     CloudToLocalLLM Application                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Flutter Frontend                        │ │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────────────────┐ │ │
│  │  │   Chat     │  │   Avatar   │  │   Desktop Control    │ │ │
│  │  │  Interface │  │   System   │  │      + Vision        │ │ │
│  │  └─────┬──────┘  └─────┬──────┘  └──────────┬───────────┘ │ │
│  │        │                │                    │              │ │
│  │  ┌─────┴────────────────┴────────────────────┴───────┐    │ │
│  │  │              Service Layer (Provider)              │    │ │
│  │  │  ┌──────────────┐  ┌──────────────────────────┐   │    │ │
│  │  │  │  Chat Service│  │  OpenClaw Manager        │   │    │ │
│  │  │  └──────────────┘  │  - Gateway Control       │   │    │ │
│  │  │                    │  - Health Monitor        │   │    │ │
│  │  │  ┌──────────────┐  │  - Agent Lifecycle       │   │    │ │
│  │  │  │ Avatar Svc   │  └──────────────────────────┘   │    │ │
│  │  │  └──────────────┘                                 │    │ │
│  │  │                                                    │    │ │
│  │  │  ┌──────────────┐  ┌──────────────┐              │    │ │
│  │  │  │ Desktop Ctrl │  │  Vision Svc  │              │    │ │
│  │  │  └──────────────┘  └──────────────┘              │    │ │
│  │  └─────────────────────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                │                                │
│  ┌─────────────────────────────┼────────────────────────────┐  │
│  │                             ↓                            │  │
│  │  ┌──────────────────────────────────────────────────────┐│  │
│  │  │              Provider/Router Layer                   ││  │
│  │  │  ┌──────────────────┐  ┌─────────────────────────┐  ││  │
│  │  │  │  Router Server   │  │  Provider Manager       │  ││  │
│  │  │  │  (Port 1337)     │  │  - OpenClaw (local)     │  ││  │
│  │  │  │  OpenAI-compatible│  │  - LM Studio           │  ││  │
│  │  │  └──────────────────┘  │  - Ollama              │  ││  │
│  │  │                         │  - Remote/Tailscale    │  ││  │
│  │  │                         └─────────────────────────┘  ││  │
│  │  └──────────────────────────────────────────────────────┘│  │
│  └────────────────────────────────────────────────────────────┘ │
│                                │                                │
└────────────────────────────────┼────────────────────────────────┘
                                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                    OpenClaw Gateway                              │
│                   (localhost:18789)                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   LLM Engine │  │ Vision Model │  │   Agent System       │  │
│  │              │  │              │  │   - Skills           │  │
│  │  - GLM-4     │  │  - OCR       │  │   - Tools            │  │
│  │  - Custom    │  │  - Analysis  │  │   - Memory           │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

                                 │ (Optional)
                                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                 Optional Cloud Services                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Auth0        │  │ Tunnel Relay │  │   Backend API        │  │
│  │ (Optional)   │  │ (Tailscale)  │  │   (Optional)         │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Frontend Architecture

### Flutter Application Structure

```
lib/
├── main.dart                      # Entry point
├── di/
│   └── locator.dart               # Service locator (two-phase DI)
├── config/
│   ├── app_config.dart            # App configuration
│   └── router.dart                # Navigation routes
├── models/                        # Data models
├── providers/                     # State management (Provider)
├── screens/                       # UI screens
│   ├── home/                      # Main chat interface
│   ├── settings/                  # Configuration screens
│   ├── dashboard/                 # OpenClaw Gateway dashboard
│   └── onboarding/                # Setup wizard
├── widgets/                       # Reusable UI components
└── services/                      # Business logic
    ├── chat/                      # Chat services
    ├── openclaw_manager/          # OpenClaw Gateway management
    ├── avatar/                    # Avatar system
    ├── desktop_control/           # GUI automation
    ├── vision/                    # Screen and camera vision
    ├── providers/                 # LLM provider adapters
    └── database/                  # Local storage (Drift)
```

### Dependency Injection

CloudToLocalLLM uses a **two-phase service initialization**:

```dart
// Phase 1: Core Services (always available)
setupCoreServices() {
  // Settings, auth detection, local brain, token storage
}

// Phase 2: Authenticated Services (after login)
setupAuthenticatedServices() {
  // Calls setupCoreServices() first
  // Then registers: TunnelService, LLMProviderManager,
  //                 StreamingChatService, etc.
}
```

---

## Service Layer

### Core Services

| Service | Location | Purpose |
|---------|----------|---------|
| `SettingsPreferenceService` | `lib/services/settings_preference_service.dart` | App settings persistence |
| `AuthService` | `lib/services/auth_service.dart` | Auth0 authentication (optional) |
| `ThemeProvider` | `lib/services/theme_provider.dart` | Theme management |
| `TokenStorageService` | `lib/services/token_storage_service.dart` | Secure token storage |

### Pillar-Specific Services

#### Chat (Pillar 1)
| Service | Location | Purpose |
|---------|----------|---------|
| `StreamingChatService` | `lib/services/streaming_chat_service.dart` | Real-time token streaming |
| `ConversationStorageService` | `lib/services/local_conversation_storage.dart` | Chat history |

#### OpenClaw Manager (Pillar 2)
| Service | Location | Purpose |
|---------|----------|---------|
| `ConnectionManagerService` | `lib/services/connection_manager_service.dart` | Gateway connection |
| `AgentStatusService` | `lib/services/agent_status_service.dart` | Health monitoring |
| `AgentLifecycleService` | `lib/services/agent_lifecycle_service.dart` | Agent lifecycle |
| `GatewayControlService` | `lib/services/openclaw_manager/gateway_control_service.dart` | Start/stop control |

#### Avatar (Pillar 3)
| Service | Location | Purpose |
|---------|----------|---------|
| `PersonalityEngine` | `lib/services/avatar/personality_engine.dart` | Trait management |
| `EvolutionTracker` | `lib/services/avatar/evolution_tracker.dart` | XP/level/achievements |
| `MemoryService` | `lib/services/avatar/memory_service.dart` | Conversation embeddings |

#### Desktop Control (Pillar 4)
| Service | Location | Purpose |
|---------|----------|---------|
| `GuiAutomationService` | `lib/services/gui_automation_service.dart` | Screenshot, vision automation |
| `SystemControlService` | `lib/services/system_control_service.dart` | Commands, processes |
| `ClipboardService` | `lib/services/desktop_control/clipboard_service.dart` | Clipboard operations |

#### Vision (Pillar 5)
| Service | Location | Purpose |
|---------|----------|---------|
| `ScreenCaptureService` | `lib/services/vision/screen_capture.dart` | Screenshot/region capture |
| `CameraCaptureService` | `lib/services/vision/camera_capture.dart` | Webcam input |
| `OcrEngine` | `lib/services/vision/ocr_engine.dart` | Text extraction |

---

## Provider/Router Layer

### Router Server (Embedded HTTP)

The Flutter app runs an embedded HTTP server on **port 1337** that provides an OpenAI-compatible API for routing LLM requests:

```
┌─────────────────────────────────────────────────────────┐
│              Router Server (Port 1337)                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │  OpenAI-Compatible Endpoints:                      │ │
│  │  - GET  /v1/models                                 │ │
│  │  - POST /v1/chat/completions                       │ │
│  │  - GET  /health                                    │ │
│  └────────────────────────────────────────────────────┘ │
│                          │                               │
│                          ↓                               │
│  ┌────────────────────────────────────────────────────┐ │
│  │              Provider Manager                       │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌──────────────┐  │ │
│  │  │  OpenClaw   │ │  LM Studio  │ │    Ollama    │  │ │
│  │  │  Adapter    │ │  Adapter    │ │   Adapter    │  │ │
│  │  └─────────────┘ └─────────────┘ └──────────────┘  │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Provider Adapters

| Provider | Adapter File | Default Port |
|----------|--------------|--------------|
| OpenClaw Gateway | `lib/services/providers/openclaw_adapter.dart` | 18789 |
| LM Studio | `lib/services/providers/lmstudio_adapter.dart` | 1234 |
| Ollama | `lib/services/providers/ollama_adapter.dart` | 11434 |

---

## Data Storage

### Local Database (Drift/SQLite)

**File**: `~/.local/share/CloudToLocalLLM/local_brain.db` (Linux)

**Tables**:
- `conversations` - Chat history
- `messages` - Individual messages
- `provider_configurations` - LLM provider settings
- `model_capacity` - Rate limit tracking
- `avatar_profiles` - Avatar state
- `achievements` - Unlocked achievements

### Cloud Storage (Optional)

**PostgreSQL** for authenticated users:
- Conversation sync
- Settings backup
- Tunnel configurations

---

## Optional Cloud Features

All cloud features are **opt-in**. The application runs entirely locally without them.

### Auth0 Authentication
- Used only for cloud sync
- Local mode available without account

### Tunneling
- **Tailscale**: Access OpenClaw on remote devices
- **SSH Tunnel**: VPS-based OpenClaw access
- **WebSocket Relay**: Cloud proxy for web clients

### Backend API
- **Express.js** server on port 8080
- Provides tunnel relay, conversation sync
- Not required for local usage

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Linux** | ✅ Full Support | Native builds, all features |
| **Windows** | ✅ Full Support | Native builds, all features |
| **Web** | 🟡 Limited | No native tray, requires backend relay |

---

## Security & Privacy

### Privacy-First Design

- **Local Processing**: All AI computations run locally via OpenClaw
- **Zero Cloud Dependencies**: Core features work offline
- **Local Storage**: Conversations stored in local SQLite
- **Optional Cloud**: Only used when explicitly configured

### Authentication (Optional)

- **Auth0**: JWT-based authentication for cloud features
- **Token Storage**: Secure local token storage
- **Auto-Refresh**: Automatic token refresh

### Network Security

- **TLS**: All cloud connections use HTTPS/WSS
- **Tunnel Security**: SSH-over-WebSocket for tunneling
- **Rate Limiting**: Request rate limiting per provider

---

## Related Documentation

- [Five Core Pillars](../SPEC.md#core-pillars) - Feature specifications
- [Implementation Plan](../development/IMPLEMENTATION_PLAN.md) - Development roadmap
- [Avatar System](AVATAR_SYSTEM.md) - Avatar architecture
- [Desktop Control](DESKTOP_CONTROL.md) - GUI automation details
- [Vision System](VISION_SYSTEM.md) - Screen and camera vision
