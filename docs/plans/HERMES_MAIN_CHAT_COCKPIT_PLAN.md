# Hermes Main Chat Cockpit Implementation Plan

**Goal:** Make the CloudToLocalLLM main chat the single channel of truth for direct chat, Hermes work/activity events, tool traces, background local-think jobs, artifacts, restart/resume events, and future cross-device sync.

**Architecture:** Do this in layers. First introduce a normalized append-only timeline event model and merge existing chat messages with local-think job events in the main chat surface. Then add compact/verbose rendering. Then persist/sync the event log. Avoid separate diagnostic panels as the primary UX; secondary tabs should only be filtered views of the same event stream.

**Current source-of-truth context:**
- Repo: `/mnt/data/projects/CloudToLocalLLM`
- Existing doc: `docs/architecture/HERMES_LOCAL_THINK_TRAIN.md`
- Existing chat surface: `lib/screens/home/home_layout.dart`
- Existing chat model: `lib/models/chat_model.dart`
- Existing local-think model/service:
  - `lib/models/local_think_job.dart`
  - `lib/services/hermes_manager/local_think_job_service.dart`
  - `lib/services/hermes_manager/local_think_ledger_process_io.dart`
  - `lib/services/hermes_manager/local_think_ledger_process_stub.dart`
  - `test/services/hermes_manager/local_think_job_service_test.dart`

---

## Product decisions

1. **Main chat is the channel of truth.**
   - User messages, assistant replies, job status cards, tool traces, restart events, and artifacts appear in one chronological timeline.
   - Jobs/tools pages may exist later, but only as filters over the same event log.

2. **No raw hidden chain-of-thought.**
   - Show work summaries, tool names, state changes, durations, result summaries, and artifact paths.
   - Raw logs stay collapsed behind explicit click/expand and must be redacted.

3. **Compact by default, verbose on demand.**
   - Normal mode: chat bubbles plus compact event cards.
   - Verbose mode: expandable tool rows and raw-log/artifact links.

4. **Local-first.**
   - First bridge local-think through `hermes-local-think-ledger list --json`.
   - Later persist a local append-only event log and sync over Tailscale/private mesh.

5. **Do not auto-launch work from UI yet.**
   - Display and inspect first.
   - Later add explicit cancel/retry/follow-up controls.

---

## Phase 0 — Protect current work

### Task 0.1: Inspect git state

Run:

```bash
cd /mnt/data/projects/CloudToLocalLLM
git status --short
```

Expected right now:

```text
?? docs/architecture/HERMES_LOCAL_THINK_TRAIN.md
?? docs/plans/HERMES_MAIN_CHAT_COCKPIT_PLAN.md
?? lib/models/local_think_job.dart
?? lib/services/hermes_manager/local_think_job_service.dart
?? lib/services/hermes_manager/local_think_ledger_process_io.dart
?? lib/services/hermes_manager/local_think_ledger_process_stub.dart
?? test/services/hermes_manager/
```

If there are unrelated modified tracked files, do not overwrite them. Prefer additive files and small targeted patches.

---

## Phase 1 — Define normalized timeline events

### Task 1.1: Add `MainChatTimelineEvent` model

**Objective:** Create a single UI-level event type that can represent chat messages and Hermes runtime events.

**Create:** `lib/models/main_chat_timeline_event.dart`

Suggested shape:

```dart
enum MainChatTimelineEventType {
  chatUser,
  chatAssistant,
  chatSystem,
  localThinkQueued,
  localThinkRunning,
  localThinkCompleted,
  localThinkFailed,
  localThinkSkipped,
  toolStarted,
  toolFinished,
  restartRecovered,
  artifactCreated,
}

class MainChatTimelineEvent {
  final String id;
  final MainChatTimelineEventType type;
  final DateTime? timestamp;
  final String title;
  final String? summary;
  final String? body;
  final String? sourceId;
  final String? artifactPath;
  final bool isVerbose;
  final bool isExpandable;
  final Map<String, Object?> metadata;

  const MainChatTimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    this.timestamp,
    this.summary,
    this.body,
    this.sourceId,
    this.artifactPath,
    this.isVerbose = false,
    this.isExpandable = false,
    this.metadata = const <String, Object?>{},
  });
}
```

**Test:** `test/models/main_chat_timeline_event_test.dart`

Verify:
- can construct user/assistant events
- can construct local-think events
- default `metadata` is empty

Run:

```bash
flutter test test/models/main_chat_timeline_event_test.dart
```

---

### Task 1.2: Add mapper from `LocalThinkJob` to timeline event

**Objective:** Convert local-think jobs into compact main-chat event cards.

**Create:** `lib/services/hermes_manager/local_think_timeline_mapper.dart`

Mapping rules:
- `queued` -> `localThinkQueued`, title `Queued background work`
- `running` -> `localThinkRunning`, title `Running background work`
- `completed` -> `localThinkCompleted`, title `Background work completed`
- `failed` -> `localThinkFailed`, title `Background work failed`
- `cancelled` -> `localThinkFailed` or add `localThinkCancelled` if preferred
- `skipped` -> `localThinkSkipped`, title `Background work skipped`
- `summary` should prefer `job.finalPreview`, except `[SILENT]` should render as `Silent wake-gate skip`.
- `timestamp` should prefer `finishedAt`, then `startedAt`, then `createdAt`.
- `sourceId = job.taskId`.
- `metadata` should include attempts/maxAttempts, dedupKey, parentTaskId, contextFrom.

**Test:** `test/services/hermes_manager/local_think_timeline_mapper_test.dart`

Run:

```bash
flutter test test/services/hermes_manager/local_think_timeline_mapper_test.dart
```

---

## Phase 2 — Merge chat messages + local-think into one feed

### Task 2.1: Add timeline composer service

**Objective:** Compose chat messages and local-think jobs into one chronological event list.

**Create:** `lib/services/hermes_manager/main_chat_timeline_composer.dart`

Inputs:
- `Conversation? conversation`
- `List<LocalThinkJob> localThinkJobs`

Output:
- `List<MainChatTimelineEvent>` sorted newest-first or oldest-first according to UI needs.

Rules:
- Preserve current reversed list behavior in `_MessageList` if the list view remains `reverse: true`.
- Chat message IDs should remain stable: `chat:${message.id}`.
- Local-think event IDs should remain stable: `local-think:${job.taskId}:${job.status.name}`.
- Deduplicate by event id.

**Test:** `test/services/hermes_manager/main_chat_timeline_composer_test.dart`

Verify:
- empty conversation + jobs still shows job events
- conversation messages + jobs merge correctly by timestamp
- stable ids
- no duplicate local-think events

Run:

```bash
flutter test test/services/hermes_manager/main_chat_timeline_composer_test.dart
```

---

## Phase 3 — Render timeline events in main chat

### Task 3.1: Add `MainChatTimelineItem` widget

**Objective:** Render both normal chat bubbles and compact Hermes event cards from one event list.

**Create:** `lib/widgets/hermes/main_chat_timeline_item.dart`

Behavior:
- For chat event types, delegate to existing `MessageBubble` where possible, or keep `_MessageList` rendering chat messages directly until refactor is complete.
- For local-think/tool/restart/artifact events, render a compact card:
  - icon by event type
  - title
  - summary/body preview
  - timestamp if available
  - small status chip
  - expand affordance if `isExpandable`
- Avoid raw logs in the initial card.

**Test:** `test/widgets/hermes/main_chat_timeline_item_test.dart`

Verify:
- completed local-think card renders title and preview
- `[SILENT]` job renders as quiet/skipped, not scary failure
- verbose metadata hidden by default

Run:

```bash
flutter test test/widgets/hermes/main_chat_timeline_item_test.dart
```

---

### Task 3.2: Replace `_MessageList` with timeline-aware list

**Objective:** Main chat shows combined chat + activity feed.

**Modify:** `lib/screens/home/home_layout.dart`

Approach:
- Add a `LocalThinkJobService` field/state inside `_ChatPaneState` or wire through Provider later.
- Poll `LocalThinkJobService.listJobs()` every 3–5 seconds on desktop only.
- Store `List<LocalThinkJob> _localThinkJobs = const [];`.
- In build, use `MainChatTimelineComposer` to combine `conversation` and `_localThinkJobs`.
- Render `MainChatTimelineItem` list.
- If there is no conversation but jobs exist, show the timeline instead of `WelcomeScreen`.
- Keep web guard: no process calls on web.

Important: keep this additive and conservative. If full replacement is risky, first insert local-think event cards at the top/bottom of current `_MessageList`, then refactor to full composer in the next pass.

Run:

```bash
flutter analyze lib/screens/home/home_layout.dart lib/widgets/hermes/main_chat_timeline_item.dart lib/services/hermes_manager/main_chat_timeline_composer.dart
flutter test test/services/hermes_manager/local_think_job_service_test.dart test/services/hermes_manager/local_think_timeline_mapper_test.dart test/services/hermes_manager/main_chat_timeline_composer_test.dart test/widgets/hermes/main_chat_timeline_item_test.dart
```

---

## Phase 4 — Add compact/verbose layers

### Task 4.1: Add UI state for verbose events

**Objective:** User can toggle event verbosity without splitting the channel of truth.

**Modify:** `lib/screens/home/home_layout.dart`

Behavior:
- Add a compact toggle in `_RuntimeChannelHeader` or beside the input:
  - `Activity: compact/verbose`
- Compact mode hides verbose/tool rows and raw metadata.
- Verbose mode shows tool/result rows under their parent event.

**Test:** widget test if feasible; otherwise verify via `flutter analyze` and manual UI check.

---

## Phase 5 — Append-only event log foundation

### Task 5.1: Add event-log storage model, but do not sync yet

**Objective:** Prepare the future Tailscale-synced channel of truth.

**Create:**
- `lib/services/hermes_manager/main_chat_event_log.dart`
- `test/services/hermes_manager/main_chat_event_log_test.dart`

Minimum behavior:
- append event
- list events
- dedupe by id
- stable ordering

Implementation can be in-memory first. Do not add database dependencies unless the app already has a standard storage abstraction.

---

## Phase 6 — Future sync, not first Codex pass

Do **not** implement Tailscale sync in the first pass unless all previous phases are green.

Future shape:
- local append-only event log as source of truth
- each device has local replica
- reconcile by event id/timestamp/vector-ish metadata
- Tailscale/private mesh transport
- encryption at rest and in transit when leaving localhost
- Telegram is an external bridge/mirror, not the private local source of truth

---

## Verification checklist

Run at minimum:

```bash
cd /mnt/data/projects/CloudToLocalLLM
flutter test test/services/hermes_manager/local_think_job_service_test.dart
flutter test test/services/hermes_manager/local_think_timeline_mapper_test.dart
flutter test test/services/hermes_manager/main_chat_timeline_composer_test.dart
flutter test test/widgets/hermes/main_chat_timeline_item_test.dart
flutter analyze lib/models/main_chat_timeline_event.dart lib/services/hermes_manager lib/widgets/hermes lib/screens/home/home_layout.dart
```

If UI wiring changed substantially:

```bash
flutter build linux --debug
```

Manual check:
- Start CloudToLocalLLM desktop.
- Main chat still sends/receives normal messages.
- Local-think jobs appear inline in the main chat timeline.
- Completed jobs show final preview.
- `[SILENT]` jobs render quietly.
- Web build/path does not try to shell out.
- No secrets/raw logs are shown by default.

---

## Codex handoff prompt

Paste this into Codex in VS Code from repo root:

```text
Implement the Hermes Main Chat Cockpit plan in docs/plans/HERMES_MAIN_CHAT_COCKPIT_PLAN.md.

Key product rule: the main chat is the channel of truth. Do not build a separate diagnostics panel as the primary surface. Merge normal chat messages and Hermes/local-think activity events into one main timeline, compact by default with verbose/expandable details later.

First pass scope:
1. Add MainChatTimelineEvent model and tests.
2. Add LocalThinkJob -> timeline mapper and tests.
3. Add MainChatTimelineComposer and tests.
4. Add a compact timeline event widget and tests.
5. Wire local-think job events into lib/screens/home/home_layout.dart conservatively. If full list replacement is risky, render local-think event cards inline with the existing chat list first, but keep the architecture pointed at one combined timeline.

Constraints:
- Preserve existing chat behavior.
- Desktop-only local-think process access; web must return empty/no-op.
- No raw chain-of-thought. Show state, summaries, tool/event metadata, artifacts, not hidden reasoning.
- Do not expose secrets or raw logs by default.
- Do not overwrite unrelated uncommitted work.
- Keep changes small and test-driven.

Run and fix:
flutter test test/services/hermes_manager/local_think_job_service_test.dart
flutter test test/services/hermes_manager/local_think_timeline_mapper_test.dart
flutter test test/services/hermes_manager/main_chat_timeline_composer_test.dart
flutter test test/widgets/hermes/main_chat_timeline_item_test.dart
flutter analyze lib/models/main_chat_timeline_event.dart lib/services/hermes_manager lib/widgets/hermes lib/screens/home/home_layout.dart

Report exactly what files changed and what tests passed.
```
