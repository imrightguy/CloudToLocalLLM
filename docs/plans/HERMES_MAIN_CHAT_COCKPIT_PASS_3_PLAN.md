# Hermes Main Chat Cockpit Pass 3 Plan

**Goal:** Make the cockpit visibly useful, not only structurally correct: local-think cards should show safe final-preview snippets and artifact affordances, and the in-memory event log should participate in the main chat without stale cross-conversation bleed.

**Architecture rule:** The main chat remains the channel of truth. Do not add a separate primary diagnostics panel. Add richer event content and safer event-log behavior inside the existing combined timeline.

---

## Current verified state

Pass 2 added:

- `MainChatEventLog`
- artifact path fields on `LocalThinkJob`
- optional bounded `LocalThinkJobService` detail enrichment via `hermes-local-think-ledger show <task> --json`
- `artifactPath` mapping in `LocalThinkTimelineMapper`
- `home_layout.dart` uses `LocalThinkJobService(enrichDetails: true, enrichLimit: 5)`

Verified locally:

```bash
/mnt/data/flutter-sdk/bin/flutter test test/models/main_chat_timeline_event_test.dart test/services/hermes_manager/local_think_job_service_test.dart test/services/hermes_manager/local_think_timeline_mapper_test.dart test/services/hermes_manager/main_chat_timeline_composer_test.dart test/services/hermes_manager/main_chat_event_log_test.dart test/widgets/hermes/main_chat_timeline_item_test.dart
# 27 tests passed

/mnt/data/flutter-sdk/bin/flutter analyze lib/models/main_chat_timeline_event.dart lib/models/local_think_job.dart lib/services/hermes_manager/local_think_job_service.dart lib/services/hermes_manager/local_think_ledger_process_io.dart lib/services/hermes_manager/local_think_ledger_process_stub.dart lib/services/hermes_manager/local_think_timeline_mapper.dart lib/services/hermes_manager/main_chat_timeline_composer.dart lib/services/hermes_manager/main_chat_event_log.dart lib/widgets/hermes/main_chat_timeline_item.dart lib/screens/home/home_layout.dart
# No issues found

/mnt/data/flutter-sdk/bin/flutter build linux --debug
# Built build/linux/x64/debug/bundle/cloudtolocalllm
```

Important remaining gap:

`hermes-local-think-ledger show <task> --json` exposes artifact paths such as `final_file`, but it still does not expose the actual final preview text. So Pass 2 can attach artifact paths to events, but cards may still display only the job name unless `final_preview` was already present.

---

## Task 1 — Add safe local-think final preview reader

**Objective:** Read short, safe previews from local-think `.final.md` files without displaying raw logs or arbitrary personal files.

**Create:** `lib/services/hermes_manager/local_think_artifact_preview_service.dart`

Suggested API:

```dart
typedef LocalThinkArtifactTextReader = Future<String> Function(String path);

class LocalThinkArtifactPreviewService {
  LocalThinkArtifactPreviewService({
    LocalThinkArtifactTextReader? textReader,
    int maxChars = 1200,
    List<String>? allowedPathPrefixes,
  });

  Future<String?> previewFinalFile(String? path);
}
```

Rules:
- Return `null` for null/empty paths.
- Only read paths that are under allowed prefixes.
  - Default allowed prefix should include `/home/rightguy/.hermes/local-think/`.
  - Keep this configurable for tests/future installs.
- Read only text final files, not logs by default.
- Truncate to `maxChars` with a clear suffix like `…`.
- Redact obvious secrets defensively:
  - `api_key=...`
  - `token=...`
  - `password=...`
  - `Bearer ...`
- Preserve `[SILENT]` handling: if the file starts with `[SILENT]`, return `[SILENT]` or `Silent wake-gate skip.` depending on mapper/UI needs.
- If file read fails, return `null`; do not throw into UI.

**Create test:** `test/services/hermes_manager/local_think_artifact_preview_service_test.dart`

Test:
- returns null for null path
- rejects path outside allowed prefix
- reads allowed path through injected reader
- truncates long text
- redacts obvious token/password/api key values
- treats read failure as null

Implementation note:
- Use a conditional IO/stub if direct `dart:io` import would break web. If this service is only called after desktop guard, direct `dart:io` can still be risky for web compilation. Prefer conditional import like the ledger process bridge.

---

## Task 2 — Enrich jobs with final preview from final file

**Objective:** After Pass 2 detail enrichment attaches `finalFile`, use the preview service to populate `finalPreview` for recent terminal jobs.

**Modify:** `lib/services/hermes_manager/local_think_job_service.dart`

Add constructor dependency:

```dart
LocalThinkArtifactPreviewService? artifactPreviewService,
bool enrichFinalPreview = true,
```

Behavior:
- Only attempt preview read when:
  - `enrichDetails == true`
  - `enrichFinalPreview == true`
  - job is terminal
  - enriched job has `finalFile`
  - `finalPreview` is null/empty
- Limit preview reads to the same bounded `enrichLimit` set; do not fan out across all jobs.
- One failed preview read must not fail the job list.
- Do not read `logFile` or `outputFile` for preview in this pass.

Add a helper on `LocalThinkJob` if useful:

```dart
LocalThinkJob copyWith({String? finalPreview, ...})
```

or extend `mergeWithJson` to merge a synthetic preview map.

**Modify tests:** `test/services/hermes_manager/local_think_job_service_test.dart`

Add tests:
- detail enrichment + final file preview populates `finalPreview`
- existing `finalPreview` is not overwritten
- preview read failure keeps job data and artifact path
- preview reader not called when `enrichDetails` false or web guard active

---

## Task 3 — Show artifact affordance without raw content

**Objective:** Main chat event cards should make artifacts discoverable while keeping raw logs hidden.

**Modify:** `lib/widgets/hermes/main_chat_timeline_item.dart`

Behavior:
- If `event.artifactPath != null`, show a compact chip/row:
  - label: `Artifact available`
  - maybe basename only, not full path by default
- Do not render raw path in compact view unless needed. Full path can be tooltip/semantics or verbose later.
- Still do not render metadata values by default.
- Keep `[SILENT]` quiet.

**Modify tests:** `test/widgets/hermes/main_chat_timeline_item_test.dart`

Add:
- event with artifactPath renders `Artifact available`
- raw full path is not visible in compact text by default
- metadata raw log remains hidden

---

## Task 4 — Put `MainChatEventLog` into home wiring safely

**Objective:** Begin using the event log in the main chat path without stale data across conversations.

**Modify:** `lib/screens/home/home_layout.dart`

Add:

```dart
final MainChatEventLog _eventLog = MainChatEventLog();
String? _lastConversationId;
```

Behavior:
- Compose events as today.
- If `conversation?.id` changes, clear `_eventLog` before appending the new events.
- Append composed events to `_eventLog`.
- Render `_eventLog.list()` rather than raw composed events.
- Keep ordering consistent with existing reversed list behavior.
- Do not persist yet.

Important:
- Local-think events are not necessarily conversation-specific. For now, clearing on conversation change is acceptable because this pass is in-memory only and avoids stale chat mixing. Persistence/sync can model global vs conversation-scoped events later.

**Test if practical:** add a unit test around `MainChatEventLog`/composer rather than a heavy HomeLayout widget test. If not practical, analyzer/build verification is acceptable.

---

## Task 5 — Avoid overlapping poll refreshes

**Objective:** Prevent slow `hermes-local-think-ledger show` calls from overlapping every 5 seconds.

**Modify:** `lib/screens/home/home_layout.dart`

Add:

```dart
bool _localThinkRefreshInFlight = false;
```

In `_refreshLocalThinkJobs`:
- if already in flight, return
- set true before await
- reset in `finally`

This matters because Pass 2 now does up to 1 list process + 5 detail processes per poll.

---

## Verification

Run and fix:

```bash
/mnt/data/flutter-sdk/bin/flutter test test/models/main_chat_timeline_event_test.dart test/services/hermes_manager/local_think_job_service_test.dart test/services/hermes_manager/local_think_artifact_preview_service_test.dart test/services/hermes_manager/local_think_timeline_mapper_test.dart test/services/hermes_manager/main_chat_timeline_composer_test.dart test/services/hermes_manager/main_chat_event_log_test.dart test/widgets/hermes/main_chat_timeline_item_test.dart

/mnt/data/flutter-sdk/bin/flutter analyze lib/models/main_chat_timeline_event.dart lib/models/local_think_job.dart lib/services/hermes_manager/local_think_job_service.dart lib/services/hermes_manager/local_think_artifact_preview_service.dart lib/services/hermes_manager/local_think_ledger_process_io.dart lib/services/hermes_manager/local_think_ledger_process_stub.dart lib/services/hermes_manager/local_think_timeline_mapper.dart lib/services/hermes_manager/main_chat_timeline_composer.dart lib/services/hermes_manager/main_chat_event_log.dart lib/widgets/hermes/main_chat_timeline_item.dart lib/screens/home/home_layout.dart

/mnt/data/flutter-sdk/bin/flutter build linux --debug
```

Manual expectation:
- Normal chat still works.
- Local-think cards remain inline in the main chat.
- Recent completed local-think jobs now show a useful final-preview snippet when a `.final.md` file exists.
- Artifact chip appears without dumping full paths/raw logs by default.
- Web build/paths still do not run local processes.
- Poll refreshes cannot overlap.
