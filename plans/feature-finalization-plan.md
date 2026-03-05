# Feature Finalization Sprint Plan

**Date**: 2026-02-27  
**Objective**: Freeze new feature development to stabilize, polish, and finalize all currently implemented features (Phase 0, Phase 1, and Conscience System Phase 1) before proceeding to Phase 2.

---

## 🎯 Sprint Overview

This stabilization sprint bridges the gap between "it works" and "it's production-ready." We will halt new feature work to execute the critical refinements identified in the [Quality Improvement Plan](quality-improvement-plan.md).

**Sprint Duration**: 1 Week
**Focus Areas**: Error recovery, connection stability, user feedback, and data validation.

---

## 📋 Action Plan by Epic

### Epic 1: Bulletproof Setup Wizard
**Goal**: Ensure users can always complete onboarding, even in edge cases.

1. **Implement Discovery Retry (SW-001)**
   - Add a "Retry Discovery" button to `local_detection_step.dart`.
   - Implement exponential backoff for automated retries.
2. **Tailscale Manual Fallback (SW-002)**
   - Update `tailscale_discovery_step.dart` to catch CLI failures.
   - Present a clean UI for users to manually enter their Tailscale IP if auto-discovery fails.
3. **State Persistence (SW-006)**
   - Modify `setup_wizard_service.dart` to save `currentStep` and selected data to `SharedPreferences` after every transition.
   - Load this state on initialization to resume aborted setups.

### Epic 2: Resilient Connections & Chat
**Goal**: Make the chat experience flawless, handling network drops gracefully.

1. **WebSocket Reconnection Jitter (CP-001)**
   - Modify `connection_manager_service.dart` reconnection logic.
   - Implement `delay = baseDelay * (1.5 ^ attempt) + random(0, 1000)ms` to prevent thundering herd issues on gateway restarts.
2. **Silent Failure Prevention (CP-003)**
   - Add a reactive `ConnectionStatusBanner` to `home_layout.dart`.
   - Listen to `GatewayHealthStatus` and show non-intrusive warnings when disconnected or reconnecting.
3. **Error Categorization & Messaging (CP-006, CP-007)**
   - Create an `ErrorCatalog` utility map mapping backend errors to user-friendly strings.
   - Classify errors (Network, Auth, Overload) to determine whether to prompt a retry or an settings change.

### Epic 3: Reliable OpenClaw Manager
**Goal**: Ensure the gateway process is robustly managed without zombie processes or hidden crashes.

1. **Operation Timeouts & Validation (OM-001, OM-002)**
   - Update `gateway_control_service.dart` `start()` and `stop()` methods with `Future.timeout(Duration(seconds: 30))`.
   - After process start, poll the gateway's `/health` endpoint before marking state as `GatewayState.running`.
2. **Zombie Process Cleanup (OM-003)**
   - Implement forced process termination (e.g., `kill -9` or `taskkill /F`) if the graceful `stop()` command times out.
3. **Adaptive Health Checks & Timeouts (OM-005, OM-006)**
   - Enforce a 5-second timeout on all health check HTTP requests.
   - Increase polling interval if the system is stable for > 1 hour; decrease interval immediately if an error is detected.

### Epic 4: Secure Conscience System Foundation
**Goal**: Harden the Phase 1 storage layer against bad data and abuse.

1. **Input Validation & Size Limits (CS-001, CS-008)**
   - Update `router_server.dart` to reject requests with body size > 50KB.
   - Update `conscience_storage_service.dart` to validate `content` length (< 10KB) and `metadata` size before database insertion.
2. **Safe Database Operations (CS-004, CS-006)**
   - Create custom `ConscienceStorageException` classes.
   - Wrap drift database calls in `try/catch` blocks that throw these typed exceptions instead of generic SQL errors.
   - Ensure `submitDecisionVerdict` handles "decision not found" cleanly.

---

## 🏃 Execution Workflow (Next Steps)

To execute this plan, the Developer/Code Agent will follow this sequence:

1. **Setup Environment**: Ensure the local test environment has a running (and stoppable) OpenClaw gateway for testing.
2. **Branching**: Work on a dedicated branch (e.g., `feature/stabilization-sprint`).
3. **Iterative Implementation**:
   - Pick one Epic at a time.
   - Implement the P0/P1 fixes listed above.
   - Run existing tests and manually verify the edge cases (e.g., simulate a network drop, kill the gateway process manually).
4. **Code Review**: Ensure all error states have UI representations and no silent failures remain.
5. **Merge & Tag**: Once all epics are complete, merge to main and tag the release as a stable baseline before resuming Phase 2.

---

**Approval**: Once this plan is confirmed, the agent should switch to **Code Mode** to begin implementing Epic 1.