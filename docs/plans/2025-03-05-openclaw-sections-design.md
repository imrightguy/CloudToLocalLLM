# OpenClaw WebUI Sections Design

**Goal:** Implement 11 placeholder sections with real data from OpenClaw Gateway APIs and existing services, featuring state-synced pop-out windows.

**Architecture:** State-synced pop-out windows using centralized Provider-based state management, card-based layouts, and unified data flow from Gateway APIs through service layer to UI components.

**Tech Stack:** Flutter 3.5+, Provider pattern, existing services (ConnectionManagerService, GatewayControlService, SubagentRegistryService, etc.), OpenClaw Gateway API (ws://127.0.0.1:18789).

---

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Main Window (Full App)                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ Channels │  │Instances │  │ Sessions │  │  Usage   │        │
│  │  [⛶]     │  │  [⛶]     │  │  [⛶]     │  │  [⛶]     │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
│  ... 11 total sections with pop-out buttons                    │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │      Service Layer (Provider)         │
        │  - ChangeNotifier for state sync      │
        │  - ConnectionManagerService           │
        │  - GatewayControlService             │
        │  - SubagentRegistryService           │
        │  - AgentStatusService                │
        │  - RateLimitManager                  │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │      OpenClaw Gateway API             │
        │      ws://127.0.0.1:18789            │
        └───────────────────────────────────────┘
```

**Common UI Patterns:**
- Card-based layouts for data display
- Refresh buttons on all screens
- Loading states with shimmer/skeleton
- Error states with retry actions
- Empty states with helpful messages
- Pop-out button (⛶) on enabled sections

---

## Section Specifications

### 1. Channels (Gateway Channels)

**Route:** `/channels` (branch index 2)

**Data Source:** OpenClaw Gateway API (`GET /api/v1/channels`)

**Layout:** List view with channel cards

**Components:**
```
┌─────────────────────────────────────────────┐
│ 🔍 Search channels...          [Refresh]    │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ #general                 💬 1,234 msgs   │ │
│ │ General discussion channel              │ │
│ │ Last: 2 min ago • 3 unread    [▶] [⛶] │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ #development             💬 567 msgs     │ │
│ │ Development discussion                   │ │
│ │ Last: 15 min ago • 0 unread    [▶] [⛶]│ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Features:**
- Channel list with name, description, message count
- Last activity timestamp
- Unread message indicator
- Click to view channel messages
- Search/filter channels
- Filter by unread/all

**Pop-out:** Yes - for monitoring multiple channels

**State Models:**
```dart
class GatewayChannel {
  final String id;
  final String name;
  final String description;
  final int messageCount;
  final DateTime lastActivity;
  final int unreadCount;
}
```

---

### 2. Instances (Gateway Processes + Model Instances)

**Route:** `/instances` (branch index 3)

**Data Sources:**
- Gateway processes: `GatewayControlService`
- Model instances: `ConnectionManagerService` (active providers)

**Layout:** Grouped cards with expanders

**Components:**
```
┌─────────────────────────────────────────────┐
│ Gateway Process                  [🔄 Refresh]│
│ ┌─────────────────────────────────────────┐ │
│ │ OpenClaw Gateway            🟢 Running   │ │
│ │ Started: 2 hours ago                    │ │
│ │ PID: 12345 • Port: 18789                │ │
│ │                [⏸ Stop] [🔄 Restart]    │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ Model Instances                                           │
│ ┌─────────────────────────────────────────┐ │
│ │ Zhipu GLM-4                🟢 Active     │ │
│ │ Requests: 3/10 concurrent               │ │
│ │ Tier: Medium • Rate limit: OK           │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ Google Gemini              🟡 Idle      │ │
│ │ Requests: 0/3 concurrent                │ │
│ │ Tier: Critical                          │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Features:**
- Gateway state display (starting/running/stopped/error)
- Start/stop/restart controls for gateway
- Model instance cards with:
  - Provider name, model ID
  - Status (active/idle/error)
  - Rate limit status
  - Concurrent request count (X/Y)
- Real-time updates

**Pop-out:** Yes - for monitoring

**State Models:**
```dart
class ModelInstanceState {
  final String provider;
  final String model;
  final String status; // active, idle, error
  final int activeRequests;
  final int maxConcurrent;
  final String tier;
  final bool rateLimited;
}
```

---

### 3. Sessions (All Session Types - Tabbed)

**Route:** `/sessions` (branch index 4)

**Data Sources:** `ConnectionManagerService`, `StreamingChatService`, `AuthService`

**Layout:** Tabbed view

**Components:**
```
┌─────────────────────────────────────────────┐
│ [WebSocket Sessions] [Conversations] [Users]│
├─────────────────────────────────────────────┤
│ Session ID        | User/Agent | Duration   │
│ ws_abc123         | system     │ 2h 15m     │
│                   | 🟢 Active  | [👁] [✕]   │
├─────────────────────────────────────────────┤
│ ws_def456         | cli-tool   │ 45m        │
│                   | 🟢 Active  | [👁] [✕]   │
└─────────────────────────────────────────────┘
```

**Features:**
- **WebSocket Sessions Tab:** Active connections, duration, actions
- **Conversations Tab:** Chat sessions with token usage, message count
- **Users Tab:** Authenticated user sessions with activity
- Each tab shows table with:
  - Session ID
  - User/agent identifier
  - Duration
  - Status (active/idle/terminated)
  - Token/message usage
  - Actions (view details, terminate)
- Filter by status

**Pop-out:** Yes - for session monitoring

---

### 4. Usage (All Metrics - Dashboard)

**Route:** `/usage` (branch index 5)

**Data Sources:** `RateLimitManager`, `ConnectionManagerService`, system metrics

**Layout:** Grid of metric cards with charts

**Components:**
```
┌─────────────────────────────────────────────┐
│ Time Range: [Today ▼]           [🔄 Refresh]│
├─────────────────┬───────────────────┬───────┤
│ Token Usage     │ Request Metrics   │       │
│ ┌─────────────┐ │ ┌───────────────┐ │       │
│ │ 1.2M tokens │ │ │ 45 req/min    │ │       │
│ │ $12.34 cost │ │ │ 99.8% success │ │       │
│ │ ▂▃▅▇▃▂▅▇    │ │ │ 125ms latency │ │       │
│ └─────────────┘ │ └───────────────┘ │       │
├─────────────────┴───────────────────┴───────┤
│ Resource Usage                                    │
│ ┌─────────────────────────────────────────┐   │
│ │ CPU: ████████░░ 45%                     │   │
│ │ Memory: ██████░░░░ 2.1GB / 8GB          │   │
│ │ Disk: ███░░░░░░░░░ 45GB / 500GB         │   │
│ │ Network: ⬇️ 12MB/s ⬆️ 3MB/s            │   │
│ └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

**Features:**
- **Token Usage Card:**
  - Total tokens used (today/week/month)
  - Cost breakdown by model
  - Rate limit status bar
  - Cost projection chart
- **Request Metrics Card:**
  - Requests per minute (live sparkline)
  - Success/failure rate (donut chart)
  - Average latency (line chart)
  - Error rate by endpoint
- **Resource Usage Card:**
  - CPU usage (gauge)
  - Memory usage (gauge)
  - Disk usage (progress bar)
  - Network I/O (line chart)
- Time range selector

**Pop-out:** Yes - for monitoring dashboard

---

### 5. Cron Jobs (Gateway + App - Separated)

**Route:** `/cron` (branch index 6)

**Data Sources:** Gateway API (`/api/v1/cron`), app scheduled tasks

**Layout:** Sectioned list

**Components:**
```
┌─────────────────────────────────────────────┐
│ [+ Create Job]                   [🔄 Refresh]│
├─────────────────────────────────────────────┤
│ Gateway Cron Jobs                                       │
│ ┌─────────────────────────────────────────┐ │
│ │ Daily Backup              [🟢 Enabled   │ │
│ │ 0 2 * * * (daily at 2AM)                │ │
│ │ Next: Tomorrow 2:00 AM  Last: ✅ Success│ │
│ │                           [▶ Run] [👁]  │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ App Scheduled Tasks                                     │
│ ┌─────────────────────────────────────────┐ │
│ │ Health Check              [🟢 Enabled   │ │
│ │ Every 30 seconds                          │ │
│ │ Next: In 12 seconds      Last: ✅ OK    │ │
│ │                           [👁]           │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Features:**
- **Gateway Cron Jobs Section:**
  - Job name, schedule (cron expression)
  - Next run time, last run status
  - Enable/disable toggle
  - View logs button
  - Run now button
- **App Scheduled Tasks Section:**
  - Task name (health check, sync, etc.)
  - Schedule, next run
  - Status indicators
- Create new job dialog

**Pop-out:** Yes - for monitoring scheduled tasks

---

### 6. Agents (Registry + Monitor + Config - Tabs)

**Route:** `/agents` (branch index 7)

**Data Sources:** `SubagentRegistryService`, `AgentStatusService`, `AgentLifecycleService`

**Layout:** Tabbed view

**Components:**
```
┌─────────────────────────────────────────────┐
│ [Registry] [Monitor] [Config]               │
├─────────────────────────────────────────────┤
│ Registry Tab Contents:                                  │
│ ┌─────────────────────────────────────────┐ │
│ │ Zoidbot                   🟢 Active     │ │
│ │ Front Agent • Registered: 2 days ago    │ │
│ │ Type: Executor • Runs: 1,234           │ │
│ │                           [⚙️] [⏸]     │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ Benjamin                 🟡 Idle       │ │
│ │ Reviewer • Registered: 2 days ago      │ │
│ │ Type: Validator • Runs: 567           │ │
│ │                           [⚙️] [⏸]     │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Features:**
- **Registry Tab:**
  - Agent list with name, type, status
  - Registration timestamp
  - Actions (configure, disable, remove)
- **Monitor Tab:**
  - Live agent activity feed
  - Agent lifecycle events
  - Performance metrics
- **Config Tab:**
  - Agent configuration forms
  - Behavior settings
  - Resource limits

**Pop-out:** Yes - for agent monitoring

---

### 7. Skills (Registry + Usage + Management)

**Route:** `/skills` (branch index 8)

**Data Sources:** `SubagentRegistryService`, skill execution logs

**Layout:** Three-column or tabbed view

**Components:**
```
┌─────────────────────────────────────────────┐
│ [Registry] [Usage] [Management]             │
├─────────────────────────────────────────────┤
│ Registry Column:                 Usage Col:  │
│ ┌─────────────────┐     ┌─────────────────┐│
│ │ code-reviewer   │     │ 127 executions  ││
│ │ [🟢 Enabled]    │     │ 98% success     ││
│ │ Reviews PRs     │     │ avg 2.3s        ││
│ │                 │     │ ▂▃▅▇▅▃▂        ││
│ │ [Configure]     │     │ Last: 5m ago    ││
│ └─────────────────┘     └─────────────────┘│
└─────────────────────────────────────────────┘
```

**Features:**
- **Registry Column/Tab:**
  - Skill name, category, description
  - Status (enabled/disabled)
  - Version info
- **Usage Column/Tab:**
  - Execution frequency chart
  - Success rate by skill
  - Average execution time
- **Management Column/Tab:**
  - Skill parameters editor
  - Configure timeouts, retries
  - Test skill button

**Pop-out:** Yes - for skill monitoring

---

### 8. Nodes (All Nodes with Health Metrics)

**Route:** `/nodes` (branch index 9)

**Data Sources:** `ProviderDiscoveryService`, `ConnectionManagerService`

**Layout:** Card grid with health indicators

**Components:**
```
┌─────────────────────────────────────────────┐
│ [+ Add Node]                    [🔄 Refresh]│
├─────────────────────────────────────────────┤
│ Local Nodes                                               │
│ ┌─────────────────────────────────────────┐ │
│ │ OpenClaw Gateway             🟢 Healthy  │ │
│ │ Latency: 2ms • Uptime: 45 days          │ │
│ │ Requests: 45 active                     │ │
│ │                           [🔄 Restart]  │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ Cloud Nodes                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ Zhipu AI                   🟢 Connected │ │
│ │ Latency: 45ms • Tier: Medium            │ │
│ │ Rate limit: 8/10 requests               │ │
│ │                           [Test] [⚙️]   │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Features:**
- **Local Nodes Section:**
  - OpenClaw Gateway status card
  - LM Studio (if detected)
  - Ollama (if detected)
  - Status badge, health metrics, last seen
- **Cloud Nodes Section:**
  - Connected provider cards
  - Latency indicator
  - Rate limit tier badge
  - Active request count
- Add new node button
- Reconnect button for disconnected nodes

**Pop-out:** Yes - for node monitoring

---

### 9. Config (Gateway + App + System - Editable)

**Route:** `/config` (branch index 10)

**Data Sources:** `SettingsPreferenceService`, `ConnectionManagerService`, environment

**Layout:** Grouped form sections

**Components:**
```
┌─────────────────────────────────────────────┐
│ [Save] [Reset] [Export] [Import]           │
├─────────────────────────────────────────────┤
│ Gateway Configuration                                  │
│ ┌─────────────────────────────────────────┐ │
│ │ Provider: Zhipu AI               [Remove]│ │
│ │ API Key: •••••••••••••••••     [Update] │ │
│ │ Model: GLM-4                            │ │
│ │ Tier: Medium                    [Change]│ │
│ └─────────────────────────────────────────┘ │
│ [+ Add Provider]                                    │
├─────────────────────────────────────────────┤
│ App Configuration                                     │
│ ┌─────────────────────────────────────────┐ │
│ │ Theme: [System ▼]                       │ │
│ │ Language: [English ▼]                   │ │
│ │ Notifications: [✓] Enabled               │ │
│ │ Tray Icon: [✓] Enabled                   │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ System Information (read-only)                         │
│ ┌─────────────────────────────────────────┐ │
│ │ Gateway: v1.2.3                         │ │
│ │ App: v0.8.0                             │ │
│ │ Config: /home/user/.config/openclaw     │ │
│ │                    [Copy Path]          │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Features:**
- **Gateway Config Section:**
  - Provider settings (add/remove/configure)
  - Model tier assignments
  - Rate limit configurations
  - Gateway auto-restart toggle
- **App Config Section:**
  - Theme selection
  - Language selection
  - Notification preferences
  - Tray icon toggle
- **System Config Section:**
  - Version info
  - Paths (read-only with copy)
- Save/Reset/Export/Import buttons

**Pop-out:** No - config stays in main window

---

### 10. Debug (Connection + API Inspector + Service Status)

**Route:** `/debug` (branch index 11)

**Data Sources:** `ConnectionManagerService`, API backend routes, all services

**Layout:** Toolkit with expandable panels

**Components:**
```
┌─────────────────────────────────────────────┐
│ [Connection Debugger] [API Inspector]       │
│ [Service Status]                                        │
├─────────────────────────────────────────────┤
│ Connection Debugger Panel                              │
│ ┌─────────────────────────────────────────┐ │
│ │ Test WebSocket Connection                │ │
│ │ URL: ws://127.0.0.1:18789       [Test]  │ │
│ │ Result: ✅ Connected (2ms latency)       │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ Test HTTP Endpoint                       │ │
│ │ GET /api/v1/health              [Send]  │ │
│ │ Result: 200 OK (5ms)                    │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ API Inspector Panel                                   │
│ ┌─────────────────────────────────────────┐ │
│ │ Method: [GET ▼]                         │ │
│ │ URL: /api/v1/models                     │ │
│ │ Headers: {...}                          │ │
│ │                              [Send]     │ │
│ │ Response: 200 OK                        │ │
│ │ {"models": [...]}                       │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Features:**
- **Connection Debugger Panel:**
  - WebSocket connection test
  - HTTP endpoint test
  - Latency measurement
  - Connection log
- **API Inspector Panel:**
  - Request builder
  - Response viewer
  - Request history
- **Service Status Panel:**
  - All services with health badges
  - Service restart buttons
  - Error details

**Pop-out:** Yes - for debugging while working

---

### 11. Logs (Gateway + App + Backend - Unified with Filtering)

**Route:** `/logs` (branch index 12)

**Data Sources:** Gateway process logs, Flutter debug logs, backend logs

**Layout:** Log viewer with filter sidebar

**Components:**
```
┌─────────────────────────────────────────────┐
│ Filters: [▼]              [Pause] [Export]  │
├─────────────────────────────────────────────┤
│ ┌─────────┬───────────┬──────────────┐     │
│ │ Source  │ Level    │ Search       │     │
│ │ ☑ Gateway│ ☑ Debug  │ ─────────    │     │
│ │ ☑ App    │ ☑ Info   │             │     │
│ │ ☑ Backend│ ☑ Warn   │             │     │
│ │          │ ☑ Error  │             │     │
│ │          │          │ [Search]    │     │
│ ├─────────┴───────────┴──────────────┤     │
│ │ Time: Last 1 hour ▼                  │     │
│ │ Auto-scroll: [✓]                     │     │
│ └──────────────────────────────────────┘     │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ 10:23:45 [INFO] Gateway started         │ │
│ │ 10:23:46 [INFO] Connected to provider   │ │
│ │ 10:23:47 [WARN] Rate limit 80% full     │ │
│ │ 10:23:48 [ERROR] Connection failed      │ │
│ │   → Stack trace: ...          [Expand] │ │
│ │ 10:23:49 [INFO] Retrying...             │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Features:**
- **Filter Sidebar:**
  - Source checkboxes (Gateway/App/Backend)
  - Level checkboxes (Debug/Info/Warn/Error)
  - Time range picker
  - Search input
  - Auto-scroll toggle
  - Clear logs button
- **Log View Area:**
  - Color-coded log lines by level
  - Timestamp, source, level, message
  - Expandable stack traces
  - Copy line button
  - Export logs button
- Live indicator with pause/resume

**Pop-out:** Yes - **primary use case**

---

## Pop-Out Window System

### Architecture

State-synchronized pop-out windows using Provider pattern:

```
┌─────────────────────────────────────────────────────────────┐
│                  Shared State Layer (Provider)              │
│  ┌────────────────────────────────────────────────────────┐│
│  │ PopOutStateManager (ChangeNotifier)                    ││
│  │ - List<PopOutWindow> openWindows                       ││
│  │ - Map<String, dynamic> sharedData                      ││
│  │ - sync() method for cross-window updates              ││
│  └────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
         │                                   │
         ▼                                   ▼
┌────────────────────┐            ┌────────────────────┐
│  Main Window       │            │  Pop-out Window    │
│  (Listens to State)│◄───────────►│  (Listens to State)│
└────────────────────┘   State Sync   └────────────────────┘
```

### Features

- **Pop-out button** (⛶) on all sections except Config
- **Per-section enable/disable** in settings
- **State synchronization** between all windows
- **Dock back button** to return to main window
- **Independent size/position** while sharing data
- **Window title bar** shows section name + "Pop-out"

### Implementation

```dart
class PopOutWindow {
  final String sectionId;
  final String sectionName;
  final int branchIndex;
  bool isVisible;
  Offset? position;
  Size? size;
}

class PopOutStateManager extends ChangeNotifier {
  List<PopOutWindow> _openWindows = [];
  Map<String, dynamic> _sharedData = {};

  void openPopOut(String sectionId, int branchIndex);
  void closePopOut(String sectionId);
  void updateSharedData(String key, dynamic value);
  void togglePopOutEnabled(String sectionId);
}
```

### Per-Section Settings

```
Settings → Pop-out Windows:
  ☑ Enable pop-out windows globally
  ☑ Channels
  ☑ Instances
  ☑ Sessions
  ☑ Usage
  ☑ Cron Jobs
  ☑ Agents
  ☑ Skills
  ☑ Nodes
  ☐ Config (disabled - stays in main)
  ☑ Debug
  ☑ Logs
```

---

## Common Components

### 1. Refreshable Screen Widget
```dart
class RefreshableScreen extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final String? errorMessage;
}
```

### 2. Loading Skeleton Widget
```dart
class LoadingSkeleton extends StatelessWidget {
  final int itemCount;
  final double height;
}
```

### 3. Empty State Widget
```dart
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}
```

### 4. Error State Widget
```dart
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
}
```

### 5. Status Badge Widget
```dart
class StatusBadge extends StatelessWidget {
  final String status; // healthy, error, warning, active, idle
  final String? label;
}
```

---

## Implementation Phases

1. **Phase 1: Common Components** - Build shared widgets (loading, empty, error states)
2. **Phase 2: Data Layer** - Create state models and API clients for each section
3. **Phase 3: Pop-Out System** - Implement PopOutStateManager and window management
4. **Phase 4: Sections (Priority Order)** - Implement sections one by one:
   - Channels (API integration)
   - Instances (service integration)
   - Sessions (multiple services)
   - Logs (unified viewer - high priority)
   - Usage (metrics dashboard)
   - Nodes (provider discovery)
   - Agents (existing services)
   - Skills (existing services)
   - Cron Jobs (API + app tasks)
   - Debug (toolkit)
   - Config (settings forms)

5. **Phase 5: Integration & Testing** - Full navigation, state sync, pop-out windows
6. **Phase 6: Polish** - Animations, transitions, error handling, performance

---

## Success Criteria

- ✅ All 11 sections display real data from APIs/services
- ✅ Pop-out windows work for 10 sections (Config stays in main)
- ✅ State syncs between main window and pop-outs
- ✅ All sections have loading, error, and empty states
- ✅ Refresh functionality works on all screens
- ✅ Navigation between all sections works smoothly
- ✅ No overflow errors or layout issues
- ✅ Performance acceptable (<100ms to load each section)
