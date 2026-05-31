# Desktop-local Security Scan Follow-up (2026-05-02)

Follow-up scope: `lib/services/desktop_control/**`, `lib/services/vision/**`,
`lib/services/openclaw_manager/**`, `lib/services/hermes_manager/**`,
`lib/services/router_server.dart` (gateway-adjacent), and related
desktop registrations in `lib/di/locator.dart`.

Source base:

- `/tmp/codex-security-scans/CloudToLocalLLM/3e80a2e3a49a_20260502T125942Z/report.md`  
  (deferred desktop-local follow-up prompt)
- Current repository code reviewed above.

## Validated desktop-local findings

### 1) Confirmed: Gateway command execution is path-based (desktop local)

- Files:
  - `lib/services/openclaw_manager/gateway_control_service.dart`
  - `lib/services/hermes_manager/hermes_gateway_control_service.dart`
  - `lib/di/locator.dart`
- Evidence:
  - OpenClaw gateway manager executes `Process.run('openclaw', [...])` with default PATH lookup.
  - Hermes gateway manager executes `Process.start('hermes-agent', ['gateway','start','--json'], runInShell: true)` and never enforces an absolute executable path.
- Confirmed impact:
  - A local user/process that can influence `PATH` (or binary placement) can potentially redirect gateway control calls to a different executable under the same account context.
  - This is a desktop-local integrity/availability risk and a local privilege-misuse vector.
- Confidence: **Medium-High** (direct command execution path is explicit in source).
- Severity: **Medium**.
- Likely attack path:
  - Attacker with local access to the same desktop profile (or controlled env) replaces/poisons `openclaw` / `hermes-agent` lookup target.
  - App user triggers gateway action (`start/stop/restart/status`) through normal UI flow.
  - Attacker binary runs in the app user context.

### 2) Confirmed / informational: Router keeps local utility endpoints unauthenticated

- File: `lib/services/router_server.dart`
- Evidence:
  - `_allowsUnauthenticatedLocalRequest()` permits only `GET /health` and `GET /v1/models`.
  - Tests enforce this behavior (`test/services/router_server_test.dart`).
- Confirmed impact:
  - On loopback today this enables status/model probes without token.
  - Not currently a remote-exposure issue because default bind host is loopback, but it remains an explicit design exposure when token is missing or not required.
- Confidence: **High**.
- Severity: **Low**.
- Likely attack path:
  - Any local process on the same machine can call these two endpoints.

## Findings marked uncertain / not confirmed in current scan

- `lib/services/desktop_control/window_manager_service.dart` and
  `lib/services/vision/**` currently do not show unauthenticated remote entry points in the codepaths reviewed.
- Native automation method handling exists (`linux/runner/platform_channels.cc`), but it is reached through Flutter method channels and is not directly exposed by an HTTP route in this follow-up scope.
- No clear evidence was found for desktop-local bypass routes tied to unauthorized cross-user data access in these files alone.

## Recommended next implementation order

1. **Tighten gateway command invocation (highest priority in follow-up scope).**
   - Resolve `openclaw` and `hermes-agent` binaries to trusted absolute paths or configurable allowlisted wrappers.
   - Replace Hermes `runInShell: true` with `runInShell: false` unless shell behavior is required.
   - Add a small injectable-process-runner seam and unit tests that assert exact command/args and shell flag usage.
2. **Keep router behavior explicit and auditable.**
   - Retain default local-only model/health behavior if intentional, but document it as a local bootstrap contract.
   - Add a regression test that confirms non-loopback bind requires explicit opt-in and that privileged routes still block without token.
3. **Re-run desktop-local threat-surface pass on method-channel calls.**
   - Validate `gui_automation` and desktop channel actions (`executeAction`, window control) for any indirect call chain that can be triggered without explicit user consent.
4. **Close loop with implementation evidence update in this same doc format.**
   - Record fixes, new test IDs, and validation commands in this plan before moving to admin-route work.

## Status summary

- Prior repo-wide finding `Desktop embedded router is unauthenticated and LAN-reachable` appears materially reduced by current code:
  - loopback default binding + token middleware in `RouterServer`
  - but no-op test coverage should remain to prevent regression.
- No code was modified in this pass.
