# Quality Improvement Plan - Feature Polish Sprint

**Date**: 2026-02-27  
**Objective**: Freeze new feature development and perfect existing implementations  
**Scope**: Phase 0, Phase 1, and Conscience System Phase 1

---

## Executive Summary

This document outlines a comprehensive quality improvement plan for all completed features. The goal is to achieve production-ready polish before advancing to Phase 2 implementation.

---

## Feature Review Matrix

| Feature Area | Component | Priority | Impact | Effort |
|--------------|-----------|----------|--------|--------|
| Setup Wizard | Error Recovery | P0 | High | Low |
| Setup Wizard | Progress Persistence | P1 | Medium | Low |
| Setup Wizard | Accessibility | P2 | Medium | Medium |
| Chat/Provider | Reconnection Logic | P0 | High | Medium |
| Chat/Provider | Error Messages | P1 | High | Low |
| Chat/Provider | Loading States | P1 | Medium | Low |
| OpenClaw Manager | Health Check Robustness | P0 | High | Medium |
| OpenClaw Manager | Status Polling | P1 | Medium | Low |
| OpenClaw Manager | Error Categorization | P1 | High | Low |
| Conscience System | Input Validation | P0 | High | Low |
| Conscience System | Error Handling | P1 | Medium | Low |
| Conscience System | Logging | P2 | Medium | Low |

---

## Phase 0: Setup Wizard Quality Improvements

### 1. Error Recovery & Resilience

**Current State**: Basic error handling with SnackBar notifications

**Issues Identified**:
- No retry mechanism for failed provider discovery
- No graceful degradation when Tailscale is unavailable
- Error messages are technical and not user-friendly

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| SW-001 | No retry on discovery failure | Add retry button with exponential backoff | `local_detection_step.dart` | P0 |
| SW-002 | Tailscale CLI failure crashes flow | Add fallback to manual IP entry | `tailscale_discovery_step.dart` | P0 |
| SW-003 | Technical error messages | Create user-friendly error message map | `setup_wizard_service.dart` | P1 |
| SW-004 | No offline detection | Add network connectivity check | `setup_wizard_service.dart` | P1 |
| SW-005 | Gateway password validation missing | Add real-time password validation | `gateway_password_step.dart` | P1 |

### 2. Progress Persistence

**Issues Identified**:
- Wizard restarts from beginning if app crashes
- User loses all progress on unexpected exit

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| SW-006 | No state persistence | Save wizard state to SharedPreferences after each step | `setup_wizard_service.dart` | P1 |
| SW-007 | No resume capability | Add resume dialog on wizard restart | `setup_wizard_screen.dart` | P2 |

### 3. User Experience

**Issues Identified**:
- No keyboard navigation support
- Step indicator doesn't show step names
- No estimated time remaining

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| SW-008 | No keyboard shortcuts | Add Enter to continue, Escape to go back | `setup_wizard_screen.dart` | P2 |
| SW-009 | Generic step indicator | Add step labels to progress indicator | `setup_wizard_screen.dart` | P2 |
| SW-010 | No time estimate | Add typical completion time estimate | `welcome_step.dart` | P3 |

### 4. Code Quality

**Issues Identified**:
- `debugPrint` statements should use proper logging
- No analytics/telemetry for funnel tracking

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| SW-011 | Debug prints in production | Replace with Logger service | `setup_wizard_screen.dart` | P2 |
| SW-012 | No funnel analytics | Add step completion events | `setup_wizard_service.dart` | P3 |

---

## Phase 1: Chat/Provider Selector Quality Improvements

### 1. Connection Resilience

**Current State**: WebSocket connection with basic error handling

**Issues Identified**:
- Reconnection attempts don't have jitter (thundering herd)
- No connection quality indicator
- WebSocket silently fails without user notification

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| CP-001 | No reconnection jitter | Add random delay to reconnection attempts | `connection_manager_service.dart` | P0 |
| CP-002 | No connection quality | Add latency/quality indicator to UI | `connection_manager_service.dart` | P1 |
| CP-003 | Silent WebSocket failures | Add connection status banner | `home_layout.dart` | P0 |
| CP-004 | No offline mode detection | Add connectivity listener | `connection_manager_service.dart` | P1 |
| CP-005 | Device identity retry | Add retry for device identity handshake | `device_identity_service.dart` | P1 |

### 2. Error Handling

**Issues Identified**:
- Generic error messages don't help users
- No distinction between temporary and permanent errors
- No error recovery suggestions

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| CP-006 | Generic error messages | Create error catalog with user-friendly messages | `llm_communication_error.dart` | P1 |
| CP-007 | No error categorization | Categorize errors: network, auth, rate-limit, server | `connection_manager_service.dart` | P1 |
| CP-008 | No recovery suggestions | Add suggested actions for each error type | `streaming_chat_service.dart` | P2 |

### 3. Loading States & Feedback

**Issues Identified**:
- No loading progress during model switching
- Streaming latency not visible
- No cancellation during long operations

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| CP-009 | No model switch feedback | Add loading overlay during provider switch | `model_selector.dart` | P1 |
| CP-010 | No streaming latency indicator | Add typing indicator with latency | `message_input.dart` | P2 |
| CP-011 | No cancellation support | Add cancel button for streaming requests | `streaming_chat_service.dart` | P2 |

### 4. Provider Selector Specific

**Issues Identified**:
- Provider list refresh requires app restart
- No provider health status
- Model list can become stale

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| CP-012 | No provider refresh | Add pull-to-refresh for provider list | `model_selector.dart` | P2 |
| CP-013 | No provider health | Show health indicator per provider | `model_selector.dart` | P2 |
| CP-014 | Stale model list | Cache models with TTL and refresh | `connection_manager_service.dart` | P2 |

---

## Phase 1: OpenClaw Manager Quality Improvements

### 1. Gateway Control Robustness

**Current State**: Process.run with basic exit code handling

**Issues Identified**:
- No timeout for start/stop operations
- No validation that gateway is actually running after start
- No cleanup of zombie processes

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| OM-001 | No operation timeout | Add 30-second timeout for start/stop | `gateway_control_service.dart` | P0 |
| OM-002 | No post-start validation | Verify HTTP health endpoint after start | `gateway_control_service.dart` | P0 |
| OM-003 | No process cleanup | Add process kill on stop timeout | `gateway_control_service.dart` | P1 |
| OM-004 | No crash detection | Parse stderr for crash signals | `gateway_control_service.dart` | P1 |

### 2. Health Check Improvements

**Issues Identified**:
- Health check interval is fixed (no adaptive)
- No health check timeout
- Health failures don't distinguish cause

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| OM-005 | Fixed health interval | Adaptive interval based on health history | `gateway_control_service.dart` | P1 |
| OM-006 | No health check timeout | Add 5-second timeout per check | `gateway_control_service.dart` | P0 |
| OM-007 | Generic health failures | Categorize: network, auth, overload, crash | `gateway_control_service.dart` | P1 |

### 3. Auto-Restart Improvements

**Issues Identified**:
- Restart attempts don't persist across app restarts
- No cooldown period between restarts
- No notification when auto-restart triggers

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| OM-008 | Restart count not persisted | Save restart count to SharedPreferences | `gateway_control_service.dart` | P2 |
| OM-009 | No cooldown period | Add 60-second cooldown between attempts | `gateway_control_service.dart` | P1 |
| OM-010 | No user notification | Show toast when auto-restart triggers | `gateway_control_service.dart` | P2 |
| OM-011 | Max attempts never resets | Reset attempts after 1 hour of stability | `gateway_control_service.dart` | P1 |

### 4. Agent Status Service

**Issues Identified**:
- Polling continues even when not visible
- No polling error recovery
- Session data not cached for offline viewing

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| OM-012 | Always polling | Pause polling when dashboard not visible | `agent_status_service.dart` | P1 |
| OM-013 | No polling error recovery | Add retry with backoff on polling failure | `agent_status_service.dart` | P1 |
| OM-014 | No offline cache | Cache last known session data | `agent_status_service.dart` | P2 |

---

## Conscience System Phase 1: Quality Improvements

### 1. Input Validation

**Issues Identified**:
- No input validation on thought/decision content
- No maximum length checks
- No sanitization of agent names

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| CS-001 | No content validation | Add max length validation (10KB limit) | `conscience_storage_service.dart` | P0 |
| CS-002 | No agent name sanitization | Validate agent names match pattern | `conscience_storage_service.dart` | P1 |
| CS-003 | No metadata size limit | Limit metadata to 1KB | `conscience_storage_service.dart` | P1 |

### 2. Error Handling

**Issues Identified**:
- Database errors propagate as generic exceptions
- No transaction rollback on partial failure
- StateError on missing decision is not user-friendly

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| CS-004 | Generic database errors | Wrap in ConscienceStorageException | `conscience_storage_service.dart` | P1 |
| CS-005 | No transaction support | Wrap insert operations in transactions | `conscience_storage_service.dart` | P2 |
| CS-006 | StateError on missing | Return null or throw typed exception | `conscience_storage_service.dart` | P1 |

### 3. API Endpoint Robustness

**Issues Identified**:
- No rate limiting on API endpoints
- No request size limits
- No authentication on endpoints

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| CS-007 | No rate limiting | Add rate limit middleware (100 req/min) | `router_server.dart` | P1 |
| CS-008 | No request size limit | Add max body size (50KB) | `router_server.dart` | P0 |
| CS-009 | No authentication | Validate requests from OpenClaw only | `router_server.dart` | P2 |

### 4. Logging & Observability

**Issues Identified**:
- No structured logging
- No metrics collection
- No audit trail for decisions

**Improvements**:

| ID | Issue | Solution | File | Priority |
|----|-------|----------|------|----------|
| CS-010 | No structured logging | Add Logger with context fields | `conscience_storage_service.dart` | P2 |
| CS-011 | No metrics | Add counters for thoughts/decisions | `router_server.dart` | P3 |
| CS-012 | No audit trail | Add audit log table for verdict changes | `drift_local_brain.dart` | P3 |

---

## Prioritized Refinement Backlog

### P0 - Critical (Must Fix Before Phase 2)

1. **SW-001**: Setup Wizard retry on discovery failure
2. **SW-002**: Tailscale fallback to manual IP
3. **CP-001**: WebSocket reconnection jitter
4. **CP-003**: Silent WebSocket failure notification
5. **OM-001**: Gateway start/stop timeout
6. **OM-002**: Post-start health validation
7. **OM-006**: Health check timeout
8. **CS-001**: Content validation
9. **CS-008**: Request size limit

### P1 - High Impact (Should Fix)

1. **SW-003**: User-friendly error messages
2. **SW-005**: Gateway password validation
3. **SW-006**: Wizard state persistence
4. **CP-002**: Connection quality indicator
5. **CP-006**: Error message catalog
6. **CP-007**: Error categorization
7. **OM-003**: Process cleanup on timeout
8. **OM-005**: Adaptive health intervals
9. **OM-009**: Auto-restart cooldown
10. **OM-012**: Pause polling when not visible
11. **CS-004**: Typed exceptions
12. **CS-007**: Rate limiting

### P2 - Medium Impact (Nice to Have)

1. **SW-008**: Keyboard navigation
2. **SW-009**: Step labels in progress
3. **CP-009**: Model switch loading overlay
4. **CP-012**: Provider refresh
5. **OM-008**: Persist restart count
6. **OM-010**: Auto-restart notification
7. **CS-005**: Transaction support
8. **CS-010**: Structured logging

### P3 - Low Priority (Future)

1. **SW-010**: Time estimate
2. **SW-012**: Funnel analytics
3. **CS-011**: Metrics collection
4. **CS-012**: Audit trail

---

## Success Metrics

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Setup completion rate | Unknown | >95% | Analytics |
| Time to complete setup | Unknown | <3 min | Analytics |
| WebSocket reconnection time | Unknown | <5 sec | Telemetry |
| Gateway start success rate | Unknown | >99% | Logs |
| Error recovery rate | Unknown | >90% | Analytics |
| User-facing error clarity | Unknown | >80% positive | Survey |

---

## Implementation Order

### Sprint 1: Critical Fixes (P0)
- Estimated: 2-3 days
- Focus: Stability and data integrity

### Sprint 2: High Impact (P1)  
- Estimated: 3-4 days
- Focus: User experience and error handling

### Sprint 3: Polish (P2)
- Estimated: 2-3 days
- Focus: UX refinements and observability

---

## Next Steps

1. **Review and approve** this quality improvement plan
2. **Switch to Code mode** to begin implementing P0 critical fixes
3. **Start with Setup Wizard** (SW-001, SW-002) as highest user impact
4. **Add unit tests** for each fix to prevent regression
5. **Update documentation** after each sprint

---

**Approval Required**: Please confirm this plan before proceeding to implementation.
