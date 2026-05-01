# CloudToLocalLLM – Architecture Codemap (Reorganized)

> **Status**: Historical codemap for the older Ollama/tunnel-centered implementation. The current orientation is agent-runtime-first and Tailscale-first: the setup wizard selects an agent runtime such as Hermes, OpenClaw, a compatible custom agent gateway, or an optional hosted agent runtime; Ollama and LM Studio are support model providers only unless wrapped by a compatible agent runtime; custom tunnel components are legacy/fallback. See [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md), [AGENT_RUNTIME_CONTRACT.md](AGENT_RUNTIME_CONTRACT.md), and [SECURE_DEVICE_MESH.md](SECURE_DEVICE_MESH.md) for the current architecture.

## Trace 0: System Overview

High-level map of the major subsystems and their responsibilities.

- **Flutter Client (lib/)**
  - Bootstrap & DI (Trace 1)
  - Auth & Authenticated Services (Trace 2)
  - Connection Orchestration (Trace 3)
  - Agent Runtime Connection (legacy Ollama trace in Trace 4)
  - Secure Transport (legacy tunnel trace in Trace 5)
  - Chat Message & Streaming (Trace 6)
  - User Tier Management (Trace 8 – client)
- **API Backend (services/api-backend/)**
  - Server Initialization & Middleware (Trace 7 – init)
  - Tunnel & Proxy Management (legacy/fallback, Trace 7 – tunnels)
  - Tier Middleware & Limits (Trace 8 – backend)
- **Streaming Proxy (services/streaming-proxy/)**
  - Per-user proxy containers for cloud streaming (legacy/fallback, Trace 7 – proxy)

---

## Trace 1: Client Bootstrap & Service Initialization

**Title:** Application Bootstrap & Core Service Registration  
**Description:** Flutter app startup sequence – initializes Sentry, Auth0, and core services, then builds the provider tree before rendering the UI.

### Flow

```text
Application Bootstrap Flow
├── main() entry point
│   ├── WidgetsFlutterBinding.ensureInitialized()
│   ├── SentryFlutter.init()                            <-- 1a
│   │   └── options.dsn = AppConfig.sentryDsn
│   ├── Auth0.initialize()                           <-- 1b
│   │   └── url, anonKey from Auth0Config
│   └── _runAppWithSentry()
│       └── runApp(CloudToLocalLLMApp)
│           └── FutureProvider<AppBootstrapData>
│               └── loadApp()
│                   └── AppBootstrapper.load()
│                       ├── _initializeSqflite()
│                       └── setupServiceLocator()       <-- 1c
│                           └── setupCoreServices()
│                               ├── SessionStorageService
│                               ├── Auth0AuthService
│                               ├── AuthService         <-- 1d, 1e
│                               ├── LocalOllamaConnectionService
│                               ├── ProviderDiscoveryService
│                               └── ThemeProvider
└── CloudToLocalLLMApp.build()
    └── _AppRouterHost.initState()
        └── _initializeRouterWhenReady()
            └── AppRouter.createRouter()                <-- 1f
                └── MaterialApp.router()
```

### Key Locations

- **1a – Sentry Initialization**  
  `lib/main.dart:67`
- **1b – Auth0 Setup**  
  `lib/main.dart:84`
- **1c – Service Locator Setup**  
  `lib/bootstrap/bootstrapper.dart:24`
- **1d – AuthService Creation**  
  `lib/di/locator.dart:70`
- **1e – Auth Initialization**  
  `lib/di/locator.dart:169`
- **1f – Router Creation**  
  `lib/main.dart:530`

---

## Trace 2: User Authentication & Authenticated Services

**Title:** User Authentication & Authenticated Services Loading  
**Description:** Login flow from Auth0 auth through to lazy registration of services that require an authenticated user.

### Flow

```text
User Authentication & Service Loading Flow
├── Auth0 Client Initialization
│   └── Auth0AuthService.initialize()                <-- 2a
│
├── AuthService Setup
│   ├── Listens to authStateChanges stream              <-- 2b
│   └── On auth state change event
│       ├── event = SIGNED_IN / SIGNED_OUT
│       └── _handleAuthenticatedSession(session)        <-- 2c
│           ├── validate session token
│           └── setupAuthenticatedServices()            <-- 2d
│               ├── verify access token present
│               ├── register TunnelService              <-- 2e
│               ├── register StreamingProxyService
│               ├── register OllamaService
│               ├── register ConnectionManagerService
│               ├── register LangChainIntegrationService & LLMProviderManager
│               ├── register EnhancedUserTierService
│               └── mark _authenticatedServicesRegistered = true
│                   └── notify listeners
│                       └── provider tree rebuild       <-- 2f
│                           └── MultiProvider updated with authed services
└── UI Reactivity
    └── CloudToLocalLLMApp rebuilds with new providers
```

### Key Locations

- **2a – Auth0 Init**  
  `lib/services/supabase_auth_service.dart:43`
- **2b – Auth State Listener**  
  `lib/services/auth_service.dart:47`
- **2c – Session Handler**  
  `lib/services/auth_service.dart:56`
- **2d – Authenticated Services Registration**  
  `lib/di/locator.dart:245`
- **2e – Tunnel Service Creation (client)**  
  `lib/di/locator.dart:318`
- **2f – Provider Tree Rebuild**  
  `lib/main.dart:307`

---

## Trace 3: Connection Orchestration (ConnectionManagerService)

**Title:** Connection Orchestration & Agent Runtime Selection
**Description:** Single decision point that historically chose between local Ollama, cloud tunnel, or no connection. Current design generalizes this to the selected agent runtime and prefers Tailscale for secure remote reachability.

### Flow

```text
Connection Orchestration Flow
├── ConnectionManagerService initialization             <-- 3d
│   ├── Injected services:
│   │   ├── Agent runtime discovery/session services
│   │   ├── TunnelService
│   │   ├── AuthService
│   │   └── Support model provider services
│   ├── runtime session listeners
│   ├── _tunnelService.addListener(_onConnectionChanged)
│   └── _authService.addListener(_onAuthChanged)
│
├── Connection Type Decision                            <-- 4f
│   └── getBestConnectionType()
│       ├── If kIsWeb:
│       │   └── cloud if hasCloudConnection else none
│       ├── If desktop:
│       │   └── prefer local if available, else cloud, else none
│       └── Exposed via ConnectionType enum (local, cloud, none)
│
├── Streaming Service Selection                         <-- 5c
│   └── getStreamingService()
│       ├── local agent runtime → agent runtime streaming service
│       ├── cloud/remote agent runtime → authenticated runtime stream
│       └── none → null (UI handles disabled state)
│
└── Model List & State Propagation
    ├── availableModels derived from active connection(s)
    ├── _onConnectionChanged()                          <-- 3e
    │   ├── _autoSelectModel()
    │   └── notifyListeners()
    └── StreamingChatService listens to updates         <-- 3f
```

### Key Locations

- **3d – Connection Manager Listener Setup**  
  `lib/services/connection_manager_service.dart:33`
- **3e – Connection Change Handler**  
  `lib/services/connection_manager_service.dart:162`
- **3f – Chat Service Update**  
  `lib/services/streaming_chat_service.dart:76`
- **4f – Connection Type Selection**  
  `lib/services/connection_manager_service.dart:44`
- **5c – Get Streaming Service**  
  `lib/services/connection_manager_service.dart:60`

---

## Trace 4: Local Support Model Provider Connection (Legacy Ollama Trace)

**Title:** Desktop Local Support Model Provider Connection Flow
**Description:** Historical desktop-only flow for connecting directly to a localhost Ollama instance; disabled on web to avoid CORS issues. Current design keeps Ollama as a support model provider path for memory/background features. Hermes, OpenClaw, compatible custom agent gateways, and optional hosted agent runtimes satisfy primary setup through the Agent Runtime Contract.

### Flow

```text
Desktop Local Ollama Connection Flow
├── Service Initialization
│   ├── Platform check (kIsWeb)                         <-- 3a
│   ├── initialize() called                             <-- 3b
│   └── Connection test begins                          <-- 3c
│
├── LocalOllamaConnectionService
│   ├── testConnection() to http://localhost:11434
│   ├── fetchModels() from Ollama API
│   ├── maintain connection state (connected, models, errors)
│   └── notifyListeners() on state change
│
├── ConnectionManager Integration                       (Trace 3)
│   └── _onConnectionChanged()                          <-- 3e
│       ├── _autoSelectModel()
│       └── notifyListeners()
│
└── UI Layer Updates
    └── StreamingChatService observes                   <-- 3f
        ├── Updates available models list
        └── Auto-selects first model when appropriate
```

### Key Locations

- **3a – Platform Detection**  
  `lib/services/local_ollama_connection_service.dart:50`
- **3b – Initialize Local Connection**  
  `lib/services/local_ollama_connection_service.dart:84`
- **3c – Connection Test Start**  
  `lib/services/local_ollama_connection_service.dart:100`

---

## Trace 5: Cloud Tunnel Establishment (Legacy/Fallback)

**Title:** Cloud Tunnel Establishment (Web/Remote)  
**Description:** SSH tunnel setup path used by older web clients or remote desktop flows when local Ollama was not available or not preferred. Current design should prefer Tailscale, the secure device mesh, and selected agent runtime paths.

### Flow

```text
Cloud Tunnel Connection Flow
├── Flutter Client
│   ├── User triggers connect in UI
│   └── TunnelService.connect()                         <-- 4a
│       ├── Guard: skip if already connected/connecting
│       ├── Retrieve userId from AuthService
│       ├── Retrieve access token                       <-- 4b
│       ├── Build TunnelConfig(userId, cloudProxyUrl)  <-- 4c
│       └── SSHTunnelClient.connect(config)
│
├── ConnectionManagerService                            (Trace 3)
│   └── Observes TunnelService state
│       └── getBestConnectionType() may choose cloud    <-- 4f
│
├── API Backend (services/api-backend/)
│   ├── initializeTunnelService()                       <-- 4d
│   │   └── new TunnelService().initialize()
│   ├── POST /api/tunnels
│   │   ├── authenticateJWT middleware
│   │   └── TunnelService.createTunnel()
│   └── Manages lifecycle of per-user streaming proxies
│
└── Streaming Proxy Container (services/streaming-proxy/)
    └── proxy-server.js startup                         <-- 4e
        ├── Reads USER_ID, LOG_LEVEL, HEALTH_PORT
        ├── Exposes /health on PORT (default 8081)
        └── TunnelHttpClient ready to proxy requests
```

### Key Locations

- **4a – Tunnel Connect Request**  
  `lib/services/tunnel_service.dart:64`
- **4b – Auth Token Retrieval**  
  `lib/services/tunnel_service.dart:88`
- **4c – Tunnel Config Creation**  
  `lib/services/tunnel_service.dart:93`
- **4d – Backend Tunnel Service Init**  
  `services/api-backend/routes/tunnels.js:36`
- **4e – Streaming Proxy Startup**  
  `services/streaming-proxy/proxy-server.js:24`
- **4f – Connection Type Selection**  
  `lib/services/connection_manager_service.dart:44`

---

## Trace 6: Chat Message Send & Streaming Response

**Title:** Chat Message Flow - Agent Runtime
**Description:** Historical end-to-end message flow from the Home screen through ConnectionManager to Ollama. Current design routes the main chat channel through the selected agent runtime; Ollama/LM Studio paths are support-model or legacy fallback paths.

### Flow

```text
Chat Message Flow
├── HomeScreen UI
│   └── _handleSendMessage(message)                     <-- 5a
│       ├── await chatService.sendMessage(message)      <-- 5b
│       └── Scroll chat list to bottom when complete
│
├── StreamingChatService Orchestration
│   ├── sendMessage()
│   │   ├── Resolves current model and connection
│   │   ├── Calls connectionManager.getStreamingService() <-- 5c (Trace 3)
│   │   ├── Sends request via selected streaming service
│   │   └── Subscribes to streaming message events
│   └── Maintains BehaviorSubject<String> for UI        <-- 5f
│
├── ConnectionManagerService                            (Trace 3)
│   ├── getBestConnectionType()
│   └── getStreamingService()
│       ├── local agent runtime → agent runtime streaming service
│       └── cloud/remote agent runtime → authenticated runtime stream
│
├── Cloud Path (when cloud selected)
│   ├── Runtime/service client builds request headers   <-- 5d
│   │   └── getValidatedAccessToken() from AuthService
│   ├── Sends HTTP request to API backend
│   └── API Backend authenticateToken middleware        <-- 5e
│       └── Proxies to selected agent runtime or legacy provider path
└── UI Streaming Updates
    └── _streamingContentSubject emits tokens           <-- 5f
        └── StreamBuilder updates chat UI in real time
```

### Key Locations

- **5a – User Sends Message**  
  `lib/screens/home_screen.dart:87`
- **5b – Chat Service Processing**  
  `lib/services/streaming_chat_service.dart:87`
- **5c – Get Streaming Service**  
  `lib/services/connection_manager_service.dart:60`
- **5d – Build Auth Headers**  
  `lib/services/ollama_service.dart:89`
- **5e – Backend Auth Middleware**  
  `services/api-backend/server.js:286`
- **5f – Stream Subject Update**  
  `lib/services/streaming_chat_service.dart:38`

---

## Trace 7: API Backend Initialization & Tunnel Management

**Title:** API Backend Initialization & Tunnel Routing  
**Description:** Node.js backend startup – Sentry, middleware, DB pools, tunnels, auth, and HTTP server.

### Server Initialization

```text
API Backend Server Initialization
├── Entry Point (server.js)
│   ├── Sentry.init()                                   <-- 6a
│   ├── Load env & imports
│   ├── Logger setup with Winston
│   └── Express app creation
│       ├── setupMiddlewarePipeline()                   <-- 6b
│       │   ├── CORS configuration
│       │   ├── Rate limiting
│       │   ├── Body parsing
│       │   └── Compression
│       ├── Database Initialization                     <-- 6c
│       │   └── initializePool() for app & auth DBs
│       ├── Service Initialization
│       │   └── initializeTunnelService()               <-- 6d
│       │       └── new TunnelService().initialize()
│       ├── Route Registration
│       │   ├── Webhook routes (pre-body-parser)
│       │   ├── Swagger docs
│       │   ├── createTunnelRoutes()                    <-- 6e
│       │   ├── Auth routes
│       │   ├── User routes
│       │   └── Admin routes
│       └── Server Start
│           └── http.createServer(app)                  <-- 6f
│               └── server.listen(PORT)
└── Graceful Shutdown
    └── Handles termination signals and in-flight requests
```

### Tunnel & Proxy Management (Backend Side of Trace 5)

```text
Tunnel & Proxy Management
├── initializeTunnelService()                           <-- 4d
│   └── tunnelService = new TunnelService()
│       └── tunnelService.initialize()
│
├── createTunnelRoutes()
│   ├── POST /api/tunnels
│   │   ├── JWT auth middleware
│   │   └── tunnelService.createTunnel()
│   └── WebSocket routes for tunnel control (if any)
│
└── Streaming Proxy Coordination
    ├── Spawns per-user streaming-proxy containers
    └── Communicates via health endpoints & config env
```

### Key Locations

- **6a – Sentry Backend Init**  
  `services/api-backend/server.js:9`
- **6b – Middleware Pipeline Setup**  
  `services/api-backend/server.js:205`
- **6c – Database Pool Init**  
  `services/api-backend/database/db-pool.js:93`
- **6d – Tunnel Service Creation (backend)**  
  `services/api-backend/routes/tunnels.js:38`
- **6e – Mount Tunnel Routes**  
  `services/api-backend/server.js:296`
- **6f – HTTP Server Creation**  
  `services/api-backend/server.js:216`

---

## Trace 8: User Tier Management & Feature Gating

**Title:** User Tier Management & Feature Gating  
**Description:** Tier-based access control across client and backend. The client queries the user’s tier and stores flags; the backend middleware enforces limits.

### 8.1 Client-Side Tier Service

```text
Client Tier Management
├── EnhancedUserTierService creation                    <-- 8a
│   ├── Injected AuthService
│   └── internal tier state (free/premium/enterprise)   <-- 8e
│
├── initialize()                                        <-- 8b
│   ├── Guard: if already initialized → skip
│   ├── If user authenticated → checkUserTier()         <-- 8c
│   └── Else → _setFreeTierDefaults()
│
├── checkUserTier()
│   ├── HTTP GET /api/user/tier with auth token
│   ├── Parse tier, expiry, feature flags               <-- 8e, 8f
│   └── Update local state & notifyListeners()
│
└── Feature Access Control
    ├── isPremiumTier getter
    ├── hasAlwaysOnContainer getter
    └── Consumed by UI and connection logic
```

**Key Client Locations**

- **8a – Tier Service Creation**  
  `lib/di/locator.dart:157`
- **8b – Tier Initialization**  
  `lib/services/enhanced_user_tier_service.dart:76`
- **8c – Tier Check API Call**  
  `lib/services/enhanced_user_tier_service.dart:86`
- **8e – Tier State Storage**  
  `lib/services/enhanced_user_tier_service.dart:20`
- **8f – Feature Flag Storage**  
  `lib/services/enhanced_user_tier_service.dart:29`

### 8.2 Backend Tier Middleware

```text
Backend Tier Middleware
├── tier-check.js middleware                            <-- 8d
│   ├── Extracts user identity from JWT / request
│   ├── Queries user_subscriptions table
│   ├── Determines effective tier (free / premium / enterprise)
│   └── Attaches tier info to request (e.g., req.userTier)
│
├── Route Integration
│   ├── /api/user/tier endpoint (for client checks)
│   ├── Chat/tunnel-related endpoints
│   │   └── Enforce per-tier limits
│   └── Admin endpoints may use tier for access control
└── Data Sources
    └── user_subscriptions and related tables control entitlements
```

**Key Backend Location**

- **8d – Backend Tier Middleware**  
  `services/api-backend/middleware/tier-check.js:104`
