# Hermes Main Chat Cockpit Phase 6 Design and Security Plan

**Status:** Design and security preparation only. Do not implement persistence,
sync, listeners, routes, or transport code from this document in the same pass.

**Goal:** Persist the main chat cockpit timeline locally as an append-only event
stream, then prepare a future private device-sync path that preserves the local
security boundary.

**Architecture:** Keep the current main chat as the channel of truth. Add a
durable local event envelope below the existing UI model, materialize safe
timeline items from that envelope, and only later add a signed private sync
envelope. Local persistence comes first; transport comes last.

**Grounding inputs:**
- `docs/plans/HERMES_MAIN_CHAT_COCKPIT_PLAN.md`
- `docs/plans/HERMES_MAIN_CHAT_COCKPIT_PASS_3_PLAN.md`
- `/tmp/codex-security-scans/CloudToLocalLLM/3e80a2e3a49a_20260502T125942Z/report.md`
- `lib/models/main_chat_timeline_event.dart`
- `lib/services/hermes_manager/main_chat_event_log.dart`
- `lib/services/hermes_manager/main_chat_timeline_composer.dart`
- `lib/screens/home/home_layout.dart`

---

## Non-Goals

Do not do these in Phase 6A:

- Do not add Tailscale transport code.
- Do not add a local HTTP/WebSocket listener.
- Do not expose any new LAN surface.
- Do not use Cloud Admin routes.
- Do not use `services/tailscale-relay/` until its fallback-secret and
  arbitrary-target findings are fixed and separately verified.
- Do not sync raw logs, prompt files, output files, hidden reasoning,
  credentials, local router tokens, secure-storage values, or full local paths.
- Do not make Telegram, Discord, or cloud services the source of truth.

---

## Current State

The current cockpit stream is UI-local:

- `MainChatTimelineEvent` is a display model with `id`, `type`, `timestamp`,
  `title`, `summary`, optional `body`, optional `artifactPath`, and metadata.
- `MainChatTimelineComposer` merges conversation messages and local-think jobs
  into one oldest-first list.
- `MainChatEventLog` is in-memory, keyed by event id, and replaces an event
  when a newer or equal-timestamp version arrives.
- `home_layout.dart` keeps the chat surface as the only primary cockpit view,
  polls local-think on desktop only, and clears the in-memory event log when
  the active conversation id changes.

That is safe for the current in-memory UI pass, but it is not enough for
durable persistence or sync:

- Chat events and global local-think events need explicit scope.
- Current chat event ids use `chat:<message.id>` and should include
  `conversationId` before persistence.
- Local artifact paths are useful locally but must not become default sync
  payloads.
- The existing Drift `AgentEvents` and `SyncQueue` tables are broad legacy
  sync shapes. Do not reuse them for cockpit sync without adding a narrower
  security-reviewed timeline schema.

---

## Phase 6 Security Decisions

1. **Local persistence before private sync.**
   - Phase 6A stores timeline records locally only.
   - No network code is allowed until local persistence, redaction, scoping,
     and replay-safe serialization tests are green.

2. **No new listener by default.**
   - Future sync must not add a listener in the first persistence step.
   - Any later listener must bind to loopback by default and require an
     explicit user-enabled private transport mode.

3. **Device destinations are server/local-inventory derived.**
   - Never trust a client-supplied `targetIp`, hostname, or route as the sync
     authority.
   - A future transport must choose peers from a paired-device inventory with
     pinned public keys and explicit user approval.

4. **Auth0 user auth is not device sync auth.**
   - A signed-in user token can identify the account, but it must not authorize
     arbitrary device-to-device sync by itself.
   - Device sync requires a paired device identity, a pinned public key, and a
     signed per-record or per-batch envelope.

5. **Existing device identity must be reviewed before reuse.**
   - `DeviceIdentityService` already has an Ed25519-shaped API.
   - Before using it for sync trust, verify key generation uses cryptographic
     randomness and that private material stays in secure storage.
   - If that review fails, fix identity generation before any sync code ships.

6. **Persist a safe event envelope, not arbitrary UI metadata.**
   - The durable schema must serialize only allowlisted fields.
   - Unknown metadata keys are dropped by default.
   - Raw log and secret-like keys are rejected even for local persistence unless
     a later explicit encrypted local-only raw-log vault is designed.

7. **Sync payloads are stricter than local payloads.**
   - Local persistence may keep local-only fields needed for desktop affordances.
   - Private sync envelopes must omit local-only fields such as full file paths,
     process command lines, prompt paths, output paths, log paths, and secure
     local tokens.

8. **Conflict resolution is deterministic and append-only.**
   - Durable rows are immutable append records.
   - The UI materializer picks the latest accepted revision for a logical
     `eventId`.
   - Remote records cannot overwrite a newer local record unless they carry a
     valid source-device signature and a higher source sequence.

9. **Executor lanes are review-bound, not self-closing.**
   - If a Paperclip execution lane is backed by a canonical GitHub issue, the
     executor-side issue must stay in an evidence-ready review state until the
     review/approval lane closes the canonical issue.
   - The executor lane must not mark itself `done` merely because it produced
     artifacts, comments, or a handoff summary.
   - If a lane only seeds child work or emits handoff evidence, it should retire
     as `cancelled` or `blocked` rather than `done`.
   - Future verification must compare the board state against GitHub as the
     source of truth before any completion is recorded.
   - Operator-ready verification evidence should include: canonical GitHub issue
     link, current GitHub issue state, current Paperclip issue state, and the
     explicit review lane that is authorized to close the work.
   - Live recurrence evidence for this rule: CLO-181 and CLO-182 both attempted
     to self-close as `done` while GitHub issue #322 remained open, so the guard
     must reject executor-created follow-on lanes from settling at `done` until
     the canonical GitHub issue is actually closed by the review-authorized
     lane.

### Board closure discipline for this lane

- GitHub issue #322 remains the canonical source of truth for this governance
  fix.
- This Paperclip lane should remain `in_review` until a review-authorized lane
  confirms the GitHub issue state and records the closure.
- Executor-created follow-on lanes must not self-close to `done` while GitHub
  #322 is open; they should remain `in_review`, `blocked`, or `cancelled`
  according to the evidence they produce.
- If future work only creates evidence or seeds follow-on work, the correct exit
  is `cancelled` or `blocked`, not `done`.

---

## Phase 7 Implementation Sketch

Add a new cockpit-specific durable record instead of storing
`MainChatTimelineEvent` directly. Suggested model name:
`MainChatTimelineRecord`.

Recommended fields:

| Field | Purpose | Sync default |
| --- | --- | --- |
| `recordId` | Immutable append row id: `<sourceDeviceId>:<eventId>:<revision>` | Yes |
| `eventId` | Logical event identity used for dedupe/materialization | Yes |
| `revision` | Monotonic revision for the same logical event on one device | Yes |
| `sourceDeviceId` | Device that created the record | Yes |
| `sourceSequence` | Monotonic per-device sequence for replay defense | Yes |
| `scope` | `conversation`, `global`, or `device` | Yes |
| `conversationId` | Required for conversation-scoped events | Yes when scoped |
| `eventType` | Serialized `MainChatTimelineEventType` | Yes |
| `sourceKind` | `chat`, `localThink`, `tool`, `runtime`, `artifact`, `sync` | Yes |
| `sourceId` | Original local source id, such as message id or task id | Yes, if safe |
| `timestampUtc` | Event time used for display ordering | Yes |
| `observedAtUtc` | Local receipt/write time | Yes |
| `title` | Safe display title | Yes |
| `summary` | Safe redacted preview | Yes |
| `bodyRedacted` | Optional redacted body for verbose mode | Opt-in |
| `artifactName` | Basename only, such as `job.final.md` | Yes |
| `localArtifactPath` | Full local file path for this device only | Never |
| `safeMetadataJson` | JSON map of allowlisted metadata labels | Yes |
| `localOnlyMetadataJson` | JSON map of local-only metadata | Never |
| `syncPolicy` | `localOnly`, `privateSync`, or `neverSync` | Controls sync |
| `sensitivity` | `status`, `personal`, `secretAdjacent`, `localPath`, `raw` | Controls sync |
| `redactionVersion` | Redaction rules used to create this record | Yes |
| `payloadVersion` | Schema version for migration | Yes |

Storage recommendation:

- Use a new Drift table in `lib/database/drift_local_brain.dart` only after
  writing serialization/redaction tests.
- Do not reuse the existing `AgentEvents` table for this stream.
- If Drift table definitions change, run:

```bash
/mnt/data/flutter-sdk/bin/dart run build_runner build --delete-conflicting-outputs
```

Local storage policy:

- `localArtifactPath` may be persisted locally only if it remains local-only and
  is never included in sync envelopes.
- Raw `body` from chat messages should not be duplicated if the existing
  conversation storage remains authoritative. Store a reference to
  `conversationId` plus message id, then materialize the body from the
  conversation store.
- If a future phase chooses to persist chat bodies in the event table, mark them
  `sensitivity: personal` and require explicit private-sync opt-in before they
  leave the device.

---

## Event Identity and Dedup Strategy

Durable identity must be stable, deterministic, and scoped.

Use these logical event id forms:

- Chat message:
  - `chat:<conversationId>:<messageId>`
  - Scope: `conversation`
  - `conversationId` is required.

- Local-think job status:
  - `local-think:<sourceDeviceId>:<taskId>:<status>`
  - Scope: `global` unless the job was explicitly launched from a conversation.
  - If launched from a conversation, keep `scope: conversation` and set
    `conversationId`.

- Tool event:
  - `tool:<conversationId>:<parentEventId>:<toolCallId>:<state>`
  - Scope: `conversation`

- Runtime health or restart event:
  - `runtime:<sourceDeviceId>:<runtimeId>:<state>:<timestampUtc>`
  - Scope: `device` or `global`, depending on whether it matters across
    devices.

- Artifact event:
  - `artifact:<sourceEventId>:<artifactHashOrStableName>`
  - Scope matches the source event.

Append and materialization rules:

- Append every accepted record with a unique `recordId`.
- Materialize one visible event per logical `eventId`.
- Pick the highest `revision` for the same `sourceDeviceId` and `eventId`.
- If two devices emit the same logical event, prefer the record signed by the
  event's `sourceDeviceId`; otherwise keep both as distinct records.
- Never use mutable display timestamps as the only dedupe key.
- Reject remote records whose `sourceDeviceId` does not match the signing key.

---

## Conversation vs Global Event Separation

Persist scope explicitly. Do not infer scope from the active UI page.

Conversation-scoped events:

- User messages.
- Assistant messages.
- Tool calls and tool results tied to a specific message.
- Local-think jobs explicitly launched as follow-up work for a conversation.
- Artifacts created as part of a conversation task.

Global events:

- Background local-think jobs not launched from a conversation.
- Runtime availability changes.
- Hermes connection events.
- Desktop approval state changes.
- Sync health events once sync exists.

Device-scoped events:

- Local-only process polling failures.
- Local desktop permission checks.
- Local artifact availability.
- Router health or local token availability.

UI query rule:

- The main chat view should materialize:
  - all events where `scope == conversation` and `conversationId` matches the
    active conversation, plus
  - safe global events that are marked `showInCockpit`, plus
  - device-scoped events only when they are safe status events.
- Do not persist a global event into a conversation just because that
  conversation is active.
- The current in-memory `clear()` on conversation switch can be replaced later
  by a scoped query. Do not carry that clear-on-switch behavior into durable
  storage.

---

## Future Private Sync Boundary

No sync transport should land until local persistence is complete.

When sync is later implemented, use a transport-independent envelope first:

```text
SignedTimelineBatch
- batchId
- sourceDeviceId
- sourcePublicKeyId
- sourceSequenceStart
- sourceSequenceEnd
- createdAtUtc
- records: List<MainChatTimelineRecordSyncEnvelope>
- signature over canonical JSON for all fields above
```

Trust requirements:

- Pair devices explicitly. A paired device record must include device id,
  public key, user-visible device name, approved scopes, and revocation state.
- Verify every batch signature before decoding records.
- Reject unsigned records.
- Reject records from unpaired or revoked devices.
- Reject replayed `sourceSequence` values.
- Reject batches whose source key does not derive the claimed `sourceDeviceId`.
- Treat clock time as display data only. Do not use clock time as proof of
  freshness.

Transport requirements for a later pass:

- Do not use `services/tailscale-relay/` until the validated relay finding is
  fixed: no fallback secret and no arbitrary client-chosen `targetIp`.
- Prefer direct private-device transport where peer identity is derived from
  the paired-device inventory and Tailscale peer identity, not from a request
  parameter.
- Any local endpoint must bind loopback by default.
- Any explicitly enabled private-network endpoint must require device auth,
  signed batches, replay protection, and per-device scope checks.
- No endpoint should accept sync writes with only ordinary user JWT auth.

---

## Secrecy and Redaction Rules

Persisted local records may contain only fields needed to re-render the cockpit.
Sync records may contain only the stricter private-sync allowlist.

Allowed by default for local persistence:

- Event id, type, scope, source device id, source id.
- Safe title and status label.
- Redacted summary.
- Timestamp and observed time.
- Attempts, max attempts, exit code, dedup key, parent task id, and context
  labels after allowlist filtering.
- Artifact basename.

Allowed for future private sync after user opt-in:

- The local persistence allowlist except local-only fields.
- Conversation message references.
- Personal chat content only when private sync is explicitly enabled for that
  conversation or account.
- Redacted final-preview snippets generated by
  `LocalThinkArtifactPreviewService`.

Never sync by default:

- Raw logs.
- Hidden chain-of-thought or model/provider reasoning traces.
- Prompt files, output files, log files, meta files, runner scripts.
- Full local paths, home directory paths, workspace paths, and local artifact
  paths.
- Auth headers, bearer tokens, API keys, passwords, local router tokens,
  refresh tokens, secure-storage values, or private keys.
- Clipboard contents, window titles, screenshots, OCR text, or desktop control
  action details unless a future explicit permissioned feature designs a
  separate sync class.
- Cloud Admin data, `/api/admin/subagents` data, `/api/admin/models` data, or
  any data obtained from unresolved admin routes.
- Tailscale relay target addresses supplied by a client.

Required redaction behavior:

- Redact obvious secret forms before local persistence and again before sync
  serialization.
- Drop unknown metadata keys.
- Keep a `redactionVersion` on each record.
- Add regression tests with keys named `token`, `password`, `api_key`,
  `authorization`, `rawLog`, `promptFile`, `outputFile`, `logFile`,
  `metaFile`, and `runnerFile`.

---

## Migration and Staging Order

### Phase 6A - Local Durable Envelope, No Database

Files:

- Create: `lib/services/hermes_manager/main_chat_timeline_record.dart`
- Create: `lib/services/hermes_manager/main_chat_timeline_sanitizer.dart`
- Test: `test/services/hermes_manager/main_chat_timeline_record_test.dart`
- Test: `test/services/hermes_manager/main_chat_timeline_sanitizer_test.dart`

Implementation:

- Add a durable record model separate from `MainChatTimelineEvent`.
- Add conversion from UI event to durable local record.
- Add conversion from durable record back to UI event.
- Add allowlist-based metadata filtering.
- Add sync-envelope serialization that excludes local-only fields.
- Keep everything in memory. Do not add Drift yet.

Required tests:

- Chat event id includes conversation id.
- Body-only non-chat detail is not serialized as compact/default text.
- Unknown metadata keys are dropped.
- Secret-like keys are redacted or dropped.
- Full artifact paths remain local-only and are absent from sync JSON.
- Artifact basename survives for display.
- Records round-trip into the current UI model.

### Phase 6B - Local Append-Only Repository

Files:

- Modify: `lib/database/drift_local_brain.dart`
- Create: `lib/services/hermes_manager/main_chat_timeline_repository.dart`
- Test: `test/services/hermes_manager/main_chat_timeline_repository_test.dart`

Implementation:

- Add a cockpit-specific Drift table after Phase 6A tests are green.
- Store immutable records by `recordId`.
- Query materialized latest events by scope and conversation id.
- Keep `localArtifactPath` in a local-only column.
- Do not add sync queue writes.

Required tests:

- Insert appends records without mutating older rows.
- Query returns latest revision per `eventId`.
- Conversation query excludes unrelated conversation records.
- Global query does not become conversation-scoped accidentally.
- Sync serialization from stored rows excludes local-only fields.
- Migration test starts from the previous schema and creates the new table.

### Phase 6C - Home Wiring to Local Persistence

Files:

- Modify: `lib/screens/home/home_layout.dart`
- Modify: `lib/services/hermes_manager/main_chat_event_log.dart` only if needed.
- Test: prefer service-level tests before any widget-heavy test.

Implementation:

- Hydrate the in-memory event log from the local repository on startup.
- Append sanitized records after composing events.
- Replace conversation-switch clearing with scoped materialization.
- Keep polling desktop-only.
- Keep compact/verbose behavior unchanged.
- Do not start sync.

Required tests:

- No-conversation plus global local-think events still renders.
- Switching conversations does not mix conversation-scoped chat events.
- Safe global local-think events can still appear in the cockpit.
- Silent events remain quiet after hydration.
- Raw metadata remains hidden after hydration.

### Phase 6D - Signed Sync Envelope, No Transport

Files:

- Create: `lib/services/hermes_manager/main_chat_timeline_sync_envelope.dart`
- Create: `lib/services/hermes_manager/main_chat_timeline_trust_store.dart`
- Test: `test/services/hermes_manager/main_chat_timeline_sync_envelope_test.dart`
- Test: `test/services/hermes_manager/main_chat_timeline_trust_store_test.dart`

Implementation:

- Add canonical JSON serialization for sync batches.
- Add signing and verification behind injectable interfaces.
- Add paired-device trust store interfaces.
- Use fake keys in tests.
- Do not open sockets, HTTP servers, WebSockets, or Tailscale connections.

Required tests:

- Valid paired-device signature is accepted.
- Unknown device signature is rejected.
- Revoked device signature is rejected.
- Replayed source sequence is rejected.
- Tampered record payload is rejected.
- Batch claiming another `sourceDeviceId` is rejected.
- Ordinary user JWT is not accepted as sync authorization.

### Phase 6E - Transport Design Review Gate

Do not start this phase until Phase 6A through 6D are complete and verified.

Gate artifact:

- `docs/plans/2026-05-09-main-chat-cockpit-transport-review-gate.md`

Before any transport code:

- Re-read the security scan.
- Verify router hardening tests still pass.
- Verify Tailscale relay findings are fixed if that service is considered.
- Write a transport-specific threat model.
- Write tests proving no unauthenticated listener, no all-interface default
  bind, no client-selected target IP, and no unpaired-device writes.

---

## Test Strategy Before Real Sync Code

Focused commands for Phase 6A:

```bash
/mnt/data/flutter-sdk/bin/flutter test test/services/hermes_manager/main_chat_timeline_record_test.dart test/services/hermes_manager/main_chat_timeline_sanitizer_test.dart test/services/hermes_manager/main_chat_event_log_test.dart test/widgets/hermes/main_chat_timeline_item_test.dart
/mnt/data/flutter-sdk/bin/flutter analyze lib/models/main_chat_timeline_event.dart lib/services/hermes_manager/main_chat_event_log.dart lib/services/hermes_manager/main_chat_timeline_record.dart lib/services/hermes_manager/main_chat_timeline_sanitizer.dart lib/widgets/hermes/main_chat_timeline_item.dart
git diff --check
```

Focused commands for Phase 6B after Drift changes:

```bash
/mnt/data/flutter-sdk/bin/dart run build_runner build --delete-conflicting-outputs
/mnt/data/flutter-sdk/bin/flutter test test/services/hermes_manager/main_chat_timeline_repository_test.dart test/services/hermes_manager/main_chat_timeline_record_test.dart test/services/hermes_manager/main_chat_timeline_sanitizer_test.dart
/mnt/data/flutter-sdk/bin/flutter analyze lib/database/drift_local_brain.dart lib/services/hermes_manager/main_chat_timeline_repository.dart
git diff --check
```

Security regression commands to keep in the loop:

```bash
/mnt/data/flutter-sdk/bin/flutter test test/services/router_server_test.dart
/mnt/data/flutter-sdk/bin/flutter test test/services/hermes_manager/main_chat_timeline_sync_envelope_test.dart test/services/hermes_manager/main_chat_timeline_trust_store_test.dart
git diff --check
```

Manual checks before any sync transport:

- Start the Linux desktop app.
- Verify local-think cards still render in the main chat.
- Verify compact mode does not show raw metadata, raw body-only details, or
  full paths.
- Verify verbose mode shows only allowlisted detail.
- Verify conversation switching does not leak chat events across conversations.
- Verify global background activity remains global and is not written into the
  active conversation.
- Verify no new process is listening on LAN interfaces.

---

## Top Risks to Guard Before Coding

1. **Accidental LAN or relay exposure.**
   - Guard with no-listener Phase 6A through 6D, loopback defaults, and tests
     before transport.

2. **Sync authorization confusion.**
   - Guard by separating user auth from paired-device signatures.

3. **Client-selected target abuse.**
   - Guard by deriving destinations from a trusted paired-device inventory.

4. **Raw local data leaving the device.**
   - Guard with local-only fields, sync allowlists, and redaction tests.

5. **Conversation/global event bleed.**
   - Guard with explicit `scope`, `conversationId`, and scoped repository
     queries.

6. **Mutable event overwrite during sync.**
   - Guard with immutable records, per-device source sequences, signatures, and
     materialized latest-revision views.

7. **Over-reuse of legacy sync tables.**
   - Guard by adding cockpit-specific schema and tests instead of reusing broad
     `AgentEvents`/`SyncQueue` behavior.

8. **Weak device identity assumptions.**
   - Guard by reviewing and testing key generation, secure storage, signature
     verification, and revocation before using device identity for sync trust.
