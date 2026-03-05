# Dispatch-Ready Stabilization Backlog

**Scope lock**: Stabilization, quality improvements, and feature finalization only for Phase 0, Phase 1, and Conscience System Phase 1.  
**Out of scope**: Any net-new product features, Phase 2/3 feature implementation, planning/admin housekeeping already completed.

## Priority Order

1. P0-1 Setup Wizard error hardening and user-safe failures
2. P0-2 Connection manager configured-endpoint correctness + reconnect control
3. P0-3 Gateway control timeout + verified startup/shutdown
4. P0-4 Conscience storage input validation + typed failure handling
5. P1-1 Setup Wizard state persistence and resume-safe transitions
6. P1-2 Connection manager error taxonomy and UI-facing status contract
7. P1-3 Gateway health-check robustness and restart cooldown policy
8. P1-4 Conscience decision update atomicity and safe not-found behavior

---

## Task P0-1 — Setup Wizard Error Hardening and User-Safe Failures

- **Status**: ✅ Done (2026-02-27)
- **Implementation note**:
  - [`lib/services/onboarding/setup_wizard_service.dart`](lib/services/onboarding/setup_wizard_service.dart): Added user-safe error mapping for scan/discovery/test/complete paths, deterministic [`completeSetup()`](lib/services/onboarding/setup_wizard_service.dart:304) failure flow, guaranteed loading reset on handled failures, custom URL validation before persistence, and structured logger usage in hardened paths.
  - [`lib/screens/onboarding/setup_wizard_screen.dart`](lib/screens/onboarding/setup_wizard_screen.dart): Removed noisy submit-flow debug prints, switched to logger-backed warning on completion failure, and deduplicated final-step error snackbar signaling.
  - [`test/services/onboarding/setup_wizard_service_test.dart`](test/services/onboarding/setup_wizard_service_test.dart): Added focused P0-1 coverage for mapped provider scan failure, mapped Tailscale discovery failure, deterministic complete-setup failure behavior, loading reset guarantees, and invalid custom URL validation.

- **Objective**: Eliminate silent/technical onboarding failures and enforce predictable wizard behavior under provider scan, Tailscale discovery, token, and save errors.
- **Exact file targets**:
  - [`SetupWizardScreen`](lib/screens/onboarding/setup_wizard_screen.dart:23)
  - [`SetupWizardService`](lib/services/onboarding/setup_wizard_service.dart:69)
- **Concrete implementation steps**:
  1. Replace raw `debugPrint` paths in submit/navigation flows with centralized logger calls and structured context.
  2. Add service-level error mapping method that converts technical exceptions into user-safe messages before writing [`WizardState.errorMessage`](lib/services/onboarding/setup_wizard_service.dart:29).
  3. Normalize all failure exits in [`completeSetup()`](lib/services/onboarding/setup_wizard_service.dart:272) to a single error handling path to avoid inconsistent button states.
  4. Ensure `isLoading` is always reset on every failure branch and no duplicate snackbars are fired.
  5. Guard against missing/invalid custom URL before persistence and return deterministic validation message.
- **Dependencies**: None.
- **Risk level**: Medium.
- **Effort estimate**: M.
- **Validation and testing steps**:
  - Add/extend widget tests for wizard submit button states and error snackbar behavior.
  - Add service tests for mapped messages on provider scan/discovery/config-save failures.
  - Manual test: simulate invalid token, invalid URL, discovery failure, and verify clean recovery.
- **Definition of Done**:
  - No raw technical exception strings are shown to end users.
  - Wizard cannot remain stuck in loading state after any handled failure.
  - All failure branches produce one deterministic UI error signal.

---

## Task P0-2 — Connection Manager Endpoint Correctness and Reconnect Control

- **Objective**: Ensure websocket connections honor configured gateway URL and reconnect predictably without thrashing.
- **Exact file targets**:
  - [`ConnectionManagerService`](lib/services/connection_manager_service.dart:60)
- **Concrete implementation steps**:
  1. Update websocket URL construction in [`_connectWebSocket()`](lib/services/connection_manager_service.dart:319) to derive from `_configuredGatewayUrl` when present instead of always using default URL.
  2. Add single-flight connection guard to prevent overlapping concurrent connect attempts.
  3. Implement bounded exponential backoff with jitter for reconnect attempts after `onError`/`onDone`.
  4. Add explicit reconnect stop conditions for auth/token failures to avoid infinite loops.
  5. Ensure stale completers in `_responseCompleters`, `_runIdToCompleter`, `_methodResponseCompleters` are cleaned on disconnect.
- **Dependencies**: P0-1 recommended for consistent error message surfaces.
- **Risk level**: High.
- **Effort estimate**: M.
- **Validation and testing steps**:
  - Unit tests: configured URL precedence, jittered retry delay bounds, single-flight connect.
  - Integration test: force socket drop and verify bounded reconnection sequence.
  - Manual test: change configured gateway URL at runtime and confirm next connect uses new endpoint.
- **Definition of Done**:
  - Websocket connects to configured endpoint when set.
  - No duplicate simultaneous connect attempts observed.
  - Disconnect/retry cycles do not leak pending completers.

---

## Task P0-3 — Gateway Start/Stop Timeout and Verified State Transitions

- **Objective**: Make gateway process control robust by enforcing operation timeouts and validating actual service readiness before state flips.
- **Exact file targets**:
  - [`GatewayControlService`](lib/services/openclaw_manager/gateway_control_service.dart:15)
- **Concrete implementation steps**:
  1. Wrap [`start()`](lib/services/openclaw_manager/gateway_control_service.dart:48) and [`stop()`](lib/services/openclaw_manager/gateway_control_service.dart:82) process calls in explicit timeout handling.
  2. Add post-start readiness probe (gateway status/health command) before setting `GatewayState.running`.
  3. Add stop fallback path when graceful stop times out/fails, including clear error state and process cleanup attempt.
  4. Ensure all transition paths clear or set `_errorMessage` consistently and avoid impossible states.
  5. Add restart attempt reset policy only after verified stable running period.
- **Dependencies**: None.
- **Risk level**: High.
- **Effort estimate**: M.
- **Validation and testing steps**:
  - Unit tests for timeout branch behavior and state transitions.
  - Manual fault injection: hang start command, hang stop command, verify controlled failure states.
  - Manual crash test: kill gateway externally and validate auto-restart logic path.
- **Definition of Done**:
  - `running` is only emitted after readiness confirmation.
  - Timeout/failure branches are deterministic and recoverable.
  - No indefinite wait on start/stop operations.

---

## Task P0-4 — Conscience Storage Validation and Typed Error Contracts

- **Objective**: Protect storage layer from malformed payloads and replace generic exceptions with typed, actionable failures.
- **Exact file targets**:
  - [`ConscienceStorageService`](lib/services/conscience_storage_service.dart:6)
- **Concrete implementation steps**:
  1. Add validation helpers for `agent`, `thoughtType`, `riskLevel`, `content`, `metadata` size and format in [`writeThought()`](lib/services/conscience_storage_service.dart:14) and [`writeDecision()`](lib/services/conscience_storage_service.dart:66).
  2. Introduce typed exceptions (validation vs storage vs not-found) and replace raw `StateError` in [`submitDecisionVerdict()`](lib/services/conscience_storage_service.dart:100).
  3. Add metadata JSON encode/decode guards with explicit fallback error mapping.
  4. Add defensive limit clamping for query `limit` arguments in read methods.
- **Dependencies**: None.
- **Risk level**: Medium.
- **Effort estimate**: S.
- **Validation and testing steps**:
  - Unit tests for invalid payloads, oversize content, bad metadata, and not-found decision updates.
  - Verify read methods behave safely for boundary limits.
- **Definition of Done**:
  - Invalid payloads are rejected with typed exceptions.
  - No generic `StateError` leaks to callers.
  - Storage methods enforce consistent validation constraints.

---

## Task P1-1 — Setup Wizard State Persistence and Resume-Safe Navigation

- **Objective**: Prevent onboarding progress loss and keep step/method state coherent after app interruptions.
- **Exact file targets**:
  - [`SetupWizardService`](lib/services/onboarding/setup_wizard_service.dart:69)
  - [`SetupWizardScreen`](lib/screens/onboarding/setup_wizard_screen.dart:23)
- **Concrete implementation steps**:
  1. Persist critical wizard state on step/method/token/url changes.
  2. Restore state on service init with validation against current dynamic step topology.
  3. Add reconciliation when method changes invalidate current step index.
  4. Clear persisted draft only on successful [`completeSetup()`](lib/services/onboarding/setup_wizard_service.dart:272).
- **Dependencies**: P0-1.
- **Risk level**: Medium.
- **Effort estimate**: M.
- **Validation and testing steps**:
  - Unit tests for save/restore and invalid-step reconciliation.
  - Manual test: close app mid-wizard and verify seamless resume.
- **Definition of Done**:
  - Wizard resumes to valid prior state after restart.
  - No out-of-range step crashes after method changes.

---

## Task P1-2 — Connection Error Taxonomy and UI-Facing Status Contract

- **Objective**: Provide stable, actionable connection failure signals for UI and support diagnostics.
- **Exact file targets**:
  - [`ConnectionManagerService`](lib/services/connection_manager_service.dart:60)
- **Concrete implementation steps**:
  1. Add internal error categorization for timeout/auth/network/protocol/parsing failures.
  2. Standardize status payload from [`getGatewayStatus()`](lib/services/connection_manager_service.dart:716) to include category + recommended action.
  3. Ensure all catch blocks assign structured `_lastError` payload source and category.
  4. Add lightweight health timestamp updates on successful message flow.
- **Dependencies**: P0-2.
- **Risk level**: Medium.
- **Effort estimate**: S.
- **Validation and testing steps**:
  - Unit tests for error category mapping by thrown exception types.
  - Manual test matrix for auth failure vs timeout vs disconnect.
- **Definition of Done**:
  - Every surfaced connection failure has category and recommended recovery action.
  - Status contract is stable for UI consumption.

---

## Task P1-3 — Gateway Health Check Robustness and Restart Cooldown

- **Objective**: Reduce restart loops and false state flaps under transient failures.
- **Exact file targets**:
  - [`GatewayControlService`](lib/services/openclaw_manager/gateway_control_service.dart:15)
- **Concrete implementation steps**:
  1. Add timeout boundary to periodic status checks in [`_startHealthCheck()`](lib/services/openclaw_manager/gateway_control_service.dart:158).
  2. Introduce cooldown window between restart attempts.
  3. Add adaptive polling interval (faster during failure recovery, slower when stable).
  4. Reset `_restartAttempts` after sustained stable operation threshold.
- **Dependencies**: P0-3.
- **Risk level**: Medium.
- **Effort estimate**: M.
- **Validation and testing steps**:
  - Unit tests for cooldown gate and attempt-reset logic.
  - Manual test: repeated crash loop to verify bounded restart behavior.
- **Definition of Done**:
  - Restart behavior is bounded and policy-driven.
  - Health checks do not create excessive process churn.

---

## Task P1-4 — Conscience Decision Update Atomicity and Read Safety

- **Objective**: Guarantee decision update consistency and robust read behavior under malformed persisted metadata.
- **Exact file targets**:
  - [`ConscienceStorageService`](lib/services/conscience_storage_service.dart:6)
- **Concrete implementation steps**:
  1. Wrap verdict update + fetch sequence in atomic transaction semantics where available.
  2. Add safe decode path in [`_thoughtToMap()`](lib/services/conscience_storage_service.dart:136) to handle corrupt metadata payloads.
  3. Add consistency checks for allowed verdict/status values before write.
  4. Emit typed storage exceptions with actionable context.
- **Dependencies**: P0-4.
- **Risk level**: Low.
- **Effort estimate**: S.
- **Validation and testing steps**:
  - Unit tests for invalid verdict values and corrupt metadata rows.
  - Verify transaction rollback behavior when second operation fails.
- **Definition of Done**:
  - Verdict updates are atomic and deterministic.
  - Corrupt metadata rows do not crash reads.

---

## Dispatch Notes for Coordinator

- Queue is stabilization-only and excludes net-new feature development.
- Dispatch order should preserve dependency chain: P0 tasks first, then P1 tasks.
- Each task is implementation-ready and can be assigned independently once dependencies are satisfied.
