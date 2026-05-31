# Main Chat Cockpit Transport Threat Model

Date: 2026-05-09

Status: review-gate evidence only. This document does not add transport code, listeners, sockets, routes, or Tailscale integration.

Scope: the future private transport path for main chat cockpit timeline sync records between paired devices.

Primary gate reference:
- `docs/plans/2026-05-09-main-chat-cockpit-transport-review-gate.md`

Implementation reference:
- `docs/plans/HERMES_MAIN_CHAT_COCKPIT_PHASE_6_PLAN.md` (Phase 6E)

## Purpose

The main chat cockpit is allowed to evolve toward private device sync only if the transport path preserves the local security boundary.

This threat model exists to close the review-gate evidence gap before any transport coding begins. The goal is not to design a public API or a general-purpose sync service. The goal is to define the minimum safe private transport posture for cockpit timeline sync.

## Protected Assets

The transport path must protect:

- cockpit timeline records
- paired-device identity and revocation state
- source sequence state used for replay defense
- local file paths and artifact locations
- command lines, prompt files, output files, and log files
- auth headers, bearer tokens, API keys, and secure storage material
- user conversation content that is not explicitly approved for sync
- trust-store state that records which devices are allowed to write

## Threat Boundaries

The transport boundary is crossed only when a sync envelope leaves one device or arrives on another.

Anything that merely exists in the local UI, local event log, or local artifact storage is still local-only until it is explicitly serialized into a private sync envelope.

No client request, route parameter, or user token is allowed to redefine the destination device.

## Required Security Properties

### 1. Authentication: no unauthenticated listener

A future transport endpoint must not accept cockpit sync traffic without authentication.

If a listener is introduced later, it must be authenticated from the first line of code. An open listener that relies on later filtering is out of scope and unsafe.

### 2. Device identity: paired-device trust only

Sync authority belongs to a paired device identity, not merely to a signed-in user.

A valid sync writer must present:

- a trusted paired-device record
- a pinned public key or equivalent verified device identity
- a signature over the canonical batch payload
- a source device id that matches the signing identity

A user JWT may identify the account, but it must not authorize device sync by itself.

### 3. Replay protection: source sequence is mandatory

The transport path must reject replayed or out-of-order records.

Each accepted batch or record must carry source-sequence state that can be compared against the trust store. The system must reject duplicate or lower sequences from the same source device.

Clock time is display data only. It is not proof of freshness.

### 4. Listener and bind policy: loopback by default

Any future local endpoint must bind to loopback by default.

Binding to `0.0.0.0` or an equivalent all-interface address is not allowed as the default behavior. If a broader bind is ever supported, it must be an explicit, audited user choice.

### 5. Route authority: destinations come from trusted inventory

A sender must not choose the target IP, hostname, or route as the source of truth.

Destination selection must come from a trusted paired-device inventory with pinned identity and approved scope. Client-supplied route parameters are not authoritative.

### 6. Local-path and log secrecy: no raw local spill

The sync path must not carry raw local file paths, runner scripts, prompt files, output files, log files, or other local-only secrets by default.

Allowed local detail is limited to safe display material such as basenames, redacted summaries, and allowlisted metadata labels.

### 7. Write authority: no unpaired-device writes

An unpaired device must not be able to write cockpit timeline sync records into the trust store or local repository.

The write path must require both trusted device identity and replay-safe sequence state.

### 8. Serialization: append-only, deterministic, and canonical

The transport payload must be deterministic and append-only.

Required behavior:

- stable canonical JSON for signing and verification
- immutable record identity
- no mutable overwrite semantics
- allowlist-based field selection
- explicit rejection of unknown or secret-like metadata keys

## Threat Scenarios

### Scenario A: unauthenticated local listener

Risk: a local listener could accept sync writes from any local process or network client.

Mitigation:
- no listener unless and until authenticated device sync is intentionally designed
- loopback default if any endpoint is introduced later
- tests that prove no listener or route code appears in the future sync-path files

### Scenario B: user token mistaken for device auth

Risk: a normal account login token could be reused to authorize device-to-device sync.

Mitigation:
- separate account auth from device auth
- require paired-device identity and signature verification
- reject user-JWT-only sync authorization

### Scenario C: spoofed destination or route injection

Risk: a sender could direct data to an attacker-controlled IP or route.

Mitigation:
- derive destinations from trusted paired-device inventory
- never accept client-selected destination authority
- validate the source device against the trusted registry

### Scenario D: replayed or tampered batch

Risk: a captured batch could be resent later or modified in transit.

Mitigation:
- sign canonical payloads
- verify signatures before decoding records
- reject duplicate source sequences
- reject tampered record payloads

### Scenario E: local secrets leaving the device

Risk: raw paths, command lines, prompt files, output files, or logs could be serialized into sync payloads.

Mitigation:
- strict allowlist serialization
- redact secret-like keys before local persistence and again before sync
- keep artifact paths local-only
- use basenames or safe display labels instead of full paths

## Evidence Mapping to the Review Gate

This threat model is intended to satisfy the gate rules in:

- `docs/plans/2026-05-09-main-chat-cockpit-transport-review-gate.md`
- `docs/plans/HERMES_MAIN_CHAT_COCKPIT_PHASE_6_PLAN.md` (Phase 6E)

The focused test evidence expected by the gate is:

- `test/services/hermes_manager/main_chat_timeline_transport_gate_test.dart`
- `test/services/hermes_manager/main_chat_timeline_sync_envelope_test.dart`
- `test/services/hermes_manager/main_chat_timeline_trust_store_test.dart`

## GO / NO-GO Rule

GO for transport coding only when all of the following are true:

- this threat model is checked in
- the focused transport-gate, sync-envelope, and trust-store tests pass
- the issue thread contains exact command evidence and pass/fail output

Otherwise the decision is NO-GO for transport coding.

## Explicit Non-Goals

This document does not authorize:

- adding sockets, listeners, routes, or WebSockets
- adding Tailscale or LAN transport code
- trusting user JWTs as device auth
- exposing client-selected destination addresses
- syncing raw local files or raw logs
- reusing broad legacy sync tables without cockpit-specific review

## Review Note

This threat model is deliberately conservative. It is acceptable to remain NO-GO until the evidence bundle is complete. It is not acceptable to start transport implementation before the evidence is green.
