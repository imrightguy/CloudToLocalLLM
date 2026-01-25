# Testing Strategy

## Overview
This document outlines the strategy to improve test coverage and reliability for the CloudToLocalLLM project. Currently, the project lacks comprehensive E2E tests and has minimal backend unit test coverage.

## Goals
1.  **Reliability:** Ensure core user flows (Login, Chat, Settings) work reliably across updates.
2.  **Safety:** Prevent regressions in backend logic (Auth, Admin, Tunnels).
3.  **Verification:** Automatically verify feature flags and platform-specific toggles where possible.

## E2E Testing (Priority: High)
**Tool:** Playwright
**Target:** Web Application (Flutter Web)

### Key Scenarios
1.  **Smoke Test:**
    *   Load application URL.
    *   Verify title and initial landing page render.
2.  **Authentication:**
    *   Perform Mock Login (bypass Auth0 UI if possible, or use test credentials).
    *   Verify redirection to Dashboard/Chat.
3.  **Settings:**
    *   Navigate to Settings page.
    *   Verify toggle states (e.g., Theme, Window Manager settings).
4.  **Chat:**
    *   Send a test message.
    *   Verify response (mocked LLM response).

**Action Item:** See GitHub Issue #44 "CICD-013: Playwright E2E Smoke (Web)".

## Unit Testing (Priority: High)
**Tool:** Jest
**Target:** Node.js Backend Services (`services/api-backend`, `services/streaming-proxy`)

### Key Areas
1.  **AuthService:**
    *   Token validation logic.
    *   User role assignment.
2.  **AdminCenterService:**
    *   Permission checks.
    *   User suspension/reactivation logic.
3.  **AlertingService:**
    *   Verify alert dispatch logic (mocking transports).
4.  **PoolMonitor:**
    *   Connection health logic.

**Action Item:** See GitHub Issue #175 "Implement Backend Unit Tests".

## Feature Verification (Priority: Medium)
**Method:** Manual / Scripted
**Target:** Completed 15 TODO items (Window Manager, etc.)

Since some features (Window Manager, System Tray) are hard to test in headless CI, manual verification checklists will be used initially.

**Action Item:** See GitHub Issue #176 "Verify Recent Feature Implementations".

## CI/CD Integration
*   **Unit Tests:** Run on every PR.
*   **E2E Tests:** Run on every PR to `main` and before release.
