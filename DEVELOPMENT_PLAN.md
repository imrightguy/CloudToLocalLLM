# CloudToLocalLLM Development Plan

**Date:** 2026-02-05
**Status:** Active Development / Beta

---

## Project Vision

**Privacy-First AI Workspace for Everyone**

Run powerful AI agents with one-click simplicity. OpenClaw provides the AI engine — your data stays on your machine unless you explicitly enable cloud relay for remote access.

### Three Pillars

1. **Privacy by Default**
   - All AI execution happens locally via OpenClaw agent system
   - Zero telemetry, no data leaving your device unless explicitly enabled
   - User has full control

2. **Agent Dashboard**
   - Real-time visibility into all your AI agents (OpenClaw, Zoidbot, custom)
   - See status, resource usage, connections at a glance
   - Polished v1 focus

3. **Universal Access**
   - Linux, Windows, macOS, Web — one app, same experience
   - Desktop apps for power users
   - Web for quick access

---

## Phase 1: Local App Foundation (Current Focus)

### Priority: Agent Dashboard Polish

**Recent Progress:**
- ✅ Zoidbot branding complete (icons, splash screen)
- ✅ Agent status dashboard navigation added
- ✅ Fixed hardcoded localhost URL (now configurable via `OPENCLAW_STATUS_URL`)
- ✅ macOS build added to CI/CD

**Remaining Work:**
1. **Retry/Backoff Logic**
   - File: `lib/services/agent_status_service.dart`
   - Implement exponential backoff on connection failures
   - Reduce unnecessary network requests during outages
   - Max 5 consecutive errors before backing off

2. **Better Error Handling**
   - File: `lib/components/agent_status_widget.dart`
   - Add loading state (initial connection)
   - Add error state (connection failures)
   - Distinguish "no agents" from "connection problem"
   - Add retry button for user recovery

3. **Configurable URLs via UI**
   - File: `lib/config/app_config.dart`
   - Allow runtime configuration (not just compile-time env vars)
   - Settings screen for OpenClaw status URL input
   - Persist via SharedPreferences

### Priority: Conversation UX

**Features:**
1. **Threaded Chats**
   - Group related messages
   - Collapse thread view
   - Quick thread navigation

2. **Search & History**
   - Full-text search across conversations
   - Export/import history
   - Delete old conversations

3. **Settings**
   - Theme selection (dark/light)
   - Font size
   - Polling interval (agent dashboard)

---

## Phase 2: Mobile Experience

### Location-Aware Agents

**Vision:** Contextual intelligence based on where you are

**Capabilities:**
1. **Follow Mode**
   - Track location (with explicit permission)
   - Proactive assistance based on context
   - Toggle on/off per agent

2. **Geofencing**
   - Trigger actions when arriving/leaving places
   - "Home" → Enable smart home automations
   - "Work" → Focus mode, reduce personal notifications
   - "Cafe" → Find nearby places, WiFi suggestions

3. **Contextual Responses**
   - "You're near [location] — want me to [action]?"
   - Automatic check-ins at important locations
   - Emergency contacts with location context

4. **Safety Features**
   - Periodic check-ins (configurable interval)
   - Emergency SOS with GPS coordinates
   - Location history for review

**Privacy-First:**
- Always ask permission before enabling tracking
- Toggle tracking on/off
- Fine-grained controls (who can see location, when)
- Local-only storage (no cloud unless enabled)
- Transparent data collection logs

### Offline Optimization

**Features:**
1. **Graceful Offline Mode**
   - Local LLM works without internet
   - Queue messages for sync when online
   - Clear offline indicator in UI

2. **Battery-Friendly Polling**
   - Reduce polling frequency when on battery
   - Pause non-essential background work
   - Smart scheduling (charge vs battery)

3. **Push Notifications**
   - Agent status changes
   - Location-triggered alerts
   - Emergency notifications

---

## Phase 3: Cloud Integrations (Future)

### Google Workspace

**Priority:** Calendar, Gmail, Drive

**Implementation Approach:**
1. **OAuth Flow**
   - Sign in with Google account
   - Grant granular permissions
   - Secure token storage (flutter_secure_storage)

2. **Calendar Integration**
   - View events in app
   - Create calendar events from agent suggestions
   - Agenda view for upcoming
   - Location-based event reminders

3. **Gmail Integration**
   - Scan inbox for urgent messages
   - Read/compose emails
   - Threaded conversation view
   - Smart search

4. **Drive Integration**
   - Access documents
   - Upload/download files
   - Share LLM outputs to Drive

**Flutter Packages:**
- `googleapis` — API access
- `google_sign_in` — Authentication
- `flutter_secure_storage` — Token persistence

### Apple Ecosystem (macOS)

**Integrations:**
1. **Calendar** — Events, scheduling
2. **Contacts** — Lookups, favorites
3. **HealthKit** — Activity tracking, sleep
4. **Reminders** — Task management

### Health & Fitness

**APIs to Consider:**
1. **Apple Health** — Native health data
2. **Google Fit** — Activity, steps
3. **Strava** — Workouts, routes
4. **Oura Ring** — Sleep, recovery, readiness

---

## Phase 4: Production Deployment

### Current Issues

**1. Cloudflare Tunnel (HTTP 530 Errors)**
- Status: Endpoints not accessible
- Cause: Cloudflared service not running or misconfigured
- Action: Verify cloudflared is running on VM

**2. Docker Swarm Status**
- Status: Unknown (services not verified)
- Action: Check if stack is deployed and healthy

**3. Security Vulnerabilities**
- Status: 12 found (8 high, 4 moderate) in Dependabot
- Action: Review and fix ASAP

### Deployment Fixes

1. **Verify Docker Swarm**
   ```bash
   ssh admin@52.173.105.54
   docker stack ls
   docker service ls
   ```

2. **Fix Cloudflared**
   ```bash
   systemctl status cloudflared
   cloudflared tunnel list
   ```

3. **Test Endpoints**
   ```bash
   curl https://cloudtolocalllm.online
   curl https://api.cloudtolocalllm.online/health
   ```

---

## Phase 5: Public Release

### Roadmap (2026)

**Q1 2026 — Foundation**
- ✅ Multi-Provider Support (OpenClaw)
- ✅ Auth0 Integration
- ✅ Tunnel Streaming
- 🔄 Desktop Apps (Linux/Windows/macOS — macOS just added)

**Q2 2026 — Mobile**
- 📱 Location-Aware Agents
- 📱 Offline Optimization
- 📱 Push Notifications
- 📱 Mobile-first UI polish

**Q3 2026 — Cloud Integrations**
- 📧 Google Workspace (Calendar, Gmail, Drive)
- 📧 Apple Ecosystem (macOS Calendar, Contacts, Health)
- 📧 Health APIs (Strava, Oura)

**Q4 2026 — Production**
- 🚀 Full production deployment
- 🚀 Monitoring & alerting
- 🚀 App Store / GitHub releases
- 🚀 Public beta testing program

---

## Technical Debt

### Immediate
1. **Fix 12 Dependabot vulnerabilities** (8 high, 4 moderate)
2. **Add retry/backoff logic** to agent status service
3. **Improve error handling** in agent status widget

### Medium Term
1. **Increase test coverage** — currently only 1 test file
2. **Add integration tests** — end-to-end flows
3. **Performance optimization** — reduce app startup time

### Long Term
1. **Architecture review** — modular services, better state management
2. **Documentation** — API docs, contribution guide
3. **Accessibility** — screen reader support, high contrast mode

---

## Construction Page Status

**File:** `lib/screens/construction_screen.dart`
**Status:** ✅ Created
**Router:** `lib/screens/construction_lazy.dart` ready for integration

**Features Shown:**
- Status banner (Beta / Active Development)
- Current features with progress bars (70-90%)
- Roadmap timeline (Q1-Q4 2025)
- Quick links (GitHub, Docs, Releases)
- Back to app navigation

---

## Next Steps (Priority Order)

1. **Finish Agent Dashboard v1** (retry logic, error states, UI config)
2. **Fix production deployment** (Cloudflare tunnel, Docker Swarm)
3. **Address security vulnerabilities** (Dependabot findings)
4. **Integrate construction page** into router
5. **Begin Phase 2 planning** (Location-aware agents architecture)
6. **Start Google Workspace OAuth** design

---

**Last Updated:** 2026-02-05 19:10 EST
