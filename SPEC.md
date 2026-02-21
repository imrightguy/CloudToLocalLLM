# CloudToLocalLLM - OpenClaw Agent Manager Specification

## Project Vision

**CloudToLocalLLM** is an OpenClaw Agent Manager that serves as a privacy-first desktop AI companion. It manages the OpenClaw Gateway, provides an evolving visual avatar with growing personality, and offers full desktop control through GUI automation and system integration. Vision capabilities enable screen understanding and camera input for enhanced agent interaction.

---

## Core Pillars

### 1. Chat Interface

- **Unified Chat**: Main interaction point with the agent
- **Conversation Management**: Create, save, organize conversations
- **Message History**: Persistent history with search
- **Multi-Model Support**: Switch between available LLM models
- **Streaming Responses**: Real-time token-by-token display

### 2. OpenClaw Gateway Management

- **Service Management**: Start, stop, monitor OpenClaw Gateway (localhost:18789)
- **Health Monitoring**: Track gateway status, response times, error rates
- **Configuration**: Manage OpenClaw settings, skills, and capabilities
- **Multi-Provider Support**: Also support LM Studio (localhost:1234), Ollama

### 3. Evolving Avatar

- **Visual Character**: 2D/3D avatar that changes appearance based on:
  - Usage patterns (active hours, interaction frequency)
  - Capabilities unlocked (new skills, tools mastered)
  - Emotional state derived from conversation sentiment
- **Personality Profile**:
  - Memory system with conversation history
  - Learned preferences and interaction patterns
  - Skill progression tracking
  - Unique personality traits that develop over time

### 4. Desktop Control

- **GUI Automation**:
  - Launch applications
  - Control windows (move, resize, focus)
  - Click, type, and interact with desktop UI
  - Vision-language model powered screen understanding
- **System Integration**:
  - File system access and management
  - Command execution
  - System resource monitoring
  - Clipboard operations

### 5. Vision Capabilities

- **Screen Understanding**:
  - Screenshot capture and analysis
  - OCR for text extraction
  - UI element detection and interaction
  - Screen state monitoring
- **Camera Input**:
  - Webcam capture for real-time vision
  - Face detection and recognition
  - Environmental awareness

---

## Technical Architecture

### Frontend (Flutter Desktop/Web)

```
lib/
├── main.dart                 # Entry point
├── di/
│   └── locator.dart          # Two-phase DI: core → authenticated
├── services/
│   ├── openclaw_manager/     # OpenClaw Gateway management
│   │   ├── gateway_service.dart
│   │   ├── health_monitor.dart
│   │   └── config_manager.dart
│   ├── avatar/               # Avatar system
│   │   ├── avatar_renderer.dart
│   │   ├── personality_engine.dart
│   │   └── evolution_tracker.dart
│   ├── desktop_control/      # Desktop automation
│   │   ├── gui_automation/
│   │   │   ├── window_manager.dart
│   │   │   ├── element_detector.dart
│   │   │   └── action_executor.dart
│   │   └── system_integration/
│   │       ├── file_manager.dart
│   │       ├── command_runner.dart
│   │       └── clipboard_service.dart
│   ├── vision/               # Vision capabilities
│   │   ├── screen_capture.dart
│   │   ├── screen_analyzer.dart
│   │   ├── camera_capture.dart
│   │   └── ocr_engine.dart
│   ├── router_server.dart    # Embedded LLM router (port 1337)
│   └── providers/           # LLM provider adapters
├── screens/
│   ├── home/                 # Main chat/agent interface
│   ├── settings/             # Configuration
│   ├── avatar/               # Avatar customization/view
│   └── desktop/              # Desktop control panel
└── database/
    └── drift/                # Local SQLite (LocalBrain)
```

### Backend Services

| Service          | Port  | Purpose                   |
| ---------------- | ----- | ------------------------- |
| API Backend      | 8080  | Express.js REST API       |
| Streaming Proxy  | 3001  | WebSocket LLM streaming   |
| OpenClaw Gateway | 18789 | Primary LLM/Vision engine |

### Dependencies

- **Flutter SDK**: >=3.5.0 <4.0.0
- **Node.js**: >=22.0.0 <25.0.0
- **OpenClaw Gateway**: Running on localhost:18789

---

## Feature Specifications

### F1: OpenClaw Gateway Manager

**F1.1: Service Control**

- Start/stop/restart OpenClaw Gateway from app UI
- Display gateway status (running/stopped/error)
- Auto-start option on app launch

**F1.2: Health Monitoring**

- Real-time status dashboard
- Request latency tracking
- Error rate monitoring
- Connection health indicators

**F1.3: Configuration**

- Gateway endpoint configuration
- Model selection
- Skill management
- Parameter tuning (temperature, max tokens, etc.)

### F2: Evolving Avatar System

**F2.1: Visual Avatar**

- 2D animated character (Lottie/spine) or 3D (Flare)
- Dynamic appearance changes based on:
  - **Growth Level**: 1-100, affects avatar maturity
  - **Mood State**: Happy/Neutral/Thoughtful/Excited
  - **Active Capabilities**: Visual indicators for unlocked skills
  - **Interaction Count**: Milestone celebrations
- Customizable base character

**F2.2: Personality Engine**

- **Memory System**: Vector store for conversation embeddings
- **Trait Tracking**: Openness, helpfulness, humor, etc.
- **Learning**: Adapts to user preferences over time
- **Consistency**: Maintains personality across sessions

**F2.3: Evolution Tracking**

- XP/level system tied to usage
- Skill unlocks at milestones
- Achievement system
- Progress visualization

### F3: Desktop Control

**F3.1: GUI Automation**

- Cross-platform window management (Windows/Linux)
- Element detection via vision
- Action execution: click, double-click, drag, type
- Application launching and focusing

**F3.2: System Integration**

- File operations (read, write, list, search)
- Shell command execution
- Environment variable access
- Process listing and management

### F4: Vision System

**F4.1: Screen Understanding**

- Full-screen and region capture
- OpenClaw-powered image analysis
- OCR for text extraction (Tesseract or OpenClaw)
- UI hierarchy reconstruction

**F4.2: Camera Integration**

- Webcam capture device selection
- Frame processing pipeline
- Privacy controls (indicator when active)

---

## User Experience

### Primary Interface

- **Chat View**: Main interaction with agent
- **Avatar View**: See and interact with evolving avatar
- **Desktop View**: Control panel for desktop automation
- **Settings**: Configuration and preferences

### Onboarding Flow

1. Detect OpenClaw Gateway availability
2. Guide user through OpenClaw setup if needed
3. Create initial avatar personality
4. Introduce core features

### Privacy Model

- All processing by default runs locally via OpenClaw
- Optional cloud relay for mobile access
- No mandatory cloud dependencies
- Local data ownership (all stored in LocalBrain SQLite)

---

## Development Guidelines

### Code Organization

- Feature-first directory structure under `lib/services/`
- Platform-aware implementations (desktop vs web)
- Strict separation of UI and business logic

### Testing

- Unit tests for services
- Integration tests for API contracts
- E2E tests for critical user flows

### Performance

- Lazy loading for avatar assets
- Debounced screen captures
- Cached LLM responses where appropriate

---

## Documentation Structure

```
docs/
├── README.md                  # Index
├── SPEC.md                   # This file - master specification
├── user-guide/
│   ├── SETUP_GUIDE.md        # Initial setup
│   ├── USER_GUIDE.md         # Usage instructions
│   └── FEATURES_GUIDE.md     # Feature deep-dives
├── architecture/
│   ├── SYSTEM_ARCHITECTURE.md
│   ├── AVATAR_SYSTEM.md
│   ├── DESKTOP_CONTROL.md
│   └── VISION_SYSTEM.md
├── development/
│   ├── SETUP_WIZARD.md
│   ├── BUILDING_GUIDE.md
│   └── API_DOCUMENTATION.md
└── operations/
    └── SELF_HOSTING.md
```

---

## Success Metrics

1. **Gateway Management**: Successfully start/stop/monitor OpenClaw Gateway
2. **Avatar Evolution**: Visual and personality changes after 100+ interactions
3. **Desktop Control**: Execute at least 5 different GUI automation tasks
4. **Vision**: Capture and analyze screen content with OpenClaw
5. **Privacy**: Zero cloud dependencies for core functionality

---

## Out of Scope (v1)

- Mobile apps (iOS/Android) - future consideration
- Real-time video streaming to avatar
- Advanced 3D avatar rendering
- Multi-monitor support
- Remote desktop control
