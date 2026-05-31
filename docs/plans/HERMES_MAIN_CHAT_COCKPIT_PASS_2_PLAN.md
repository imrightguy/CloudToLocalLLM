# Hermes Main Chat Cockpit Pass 2 Plan

**Goal:** Harden the first combined main-chat timeline pass by adding a canonical event-log abstraction and improving local-think event fidelity: previews, artifact paths, safer process handling, and less noisy polling.

**Architecture:** Keep the main chat as the channel of truth. `MainChatTimelineEvent` is the canonical UI/event shape. The first pass merged conversation messages and local-think jobs into one timeline; this pass adds a small local event-log abstraction and enriches local-think events without exposing raw logs or hidden reasoning.

---

## Current verified state

Pass 1 created:

- `lib/models/main_chat_timeline_event.dart`
- `lib/services/hermes_manager/local_think_timeline_mapper.dart`
- `lib/services/hermes_manager/main_chat_timeline_composer.dart`
- `lib/widgets/hermes/main_chat_timeline_item.dart`
- `home_layout.dart` polling + combined timeline wiring

Verified locally with:

```bash
/mnt/data/flutter-sdk/bin/flutter test test/models/main_chat_timeline_event_test.dart test/services/hermes_manager/local_think_job_service_test.dart test/services/hermes_manager/local_think_timeline_mapper_test.dart test/services/hermes_manager/main_chat_timeline_composer_test.dart test/widgets/hermes/main_chat_timeline_item_test.dart
# 19 tests passed

/mnt/data/flutter-sdk/bin/flutter analyze lib/models/main_chat_timeline_event.dart lib/models/local_think_job.dart lib/services/hermes_manager/local_think_job_service.dart lib/services/hermes_manager/local_think_ledger_process_io.dart lib/services/hermes_manager/local_think_ledger_process_stub.dart lib/services/hermes_manager/local_think_timeline_mapper.dart lib/services/hermes_manager/main_chat_timeline_composer.dart lib/widgets/hermes/main_chat_timeline_item.dart lib/screens/home/home_layout.dart
# No issues found

/mnt/data/flutter-sdk/bin/flutter build linux --debug
# Built build/linux/x64/debug/bundle/cloudtolocalllm
```

Important discovered gap:

```bash
hermes-local-think-ledger list --json --limit 3
```

currently returns compact rows with fields like `task_id`, `status`, `name`, `created_at`, `finished_at`, but **does not include `final_preview`, `final_file`, `log_file`, or artifact paths**. The `show` command includes artifact paths:

```bash
hermes-local-think-ledger show <task-prefix> --json
```

So the current UI can show job cards, but older/current ledger-list cards may only show job names, not final previews/artifacts.

---

## Task 1 — Add canonical event-log abstraction

**Objective:** Add the foundation for the future local-first/Tailscale-synced channel of truth.

**Create:** `lib/services/hermes_manager/main_chat_event_log.dart`

Minimum API:

```dart
class MainChatEventLog {
  final Map<String, MainChatTimelineEvent> _eventsById = {};

  void append(MainChatTimelineEvent event) { ... }
  void appendAll(Iterable<MainChatTimelineEvent> events) { ... }
  List<MainChatTimelineEvent> list({bool newestFirst = false}) { ... }
  MainChatTimelineEvent? getById(String id) { ... }
  void clear() { ... }
}
```

Rules:
- Deduplicate by `event.id`.
- If the same id is appended again, replace it only if the incoming event has a newer/equal timestamp or the existing timestamp is null. This lets running jobs become completed jobs later when ids match in future event designs.
- Stable ordering by timestamp, then id.
- In-memory only for now. Do not add DB/storage dependency yet.

**Create test:** `test/services/hermes_manager/main_chat_event_log_test.dart`

Test:
- append/list mixed event types
- dedupe by id
- replacement behavior for same id with newer timestamp
- stable ordering for null timestamps and equal timestamps

---

## Task 2 — Preserve artifact-path fields on `LocalThinkJob`

**Objective:** Let timeline cards point at final/log artifacts when the ledger provides those fields.

**Modify:** `lib/models/local_think_job.dart`

Add optional fields:

```dart
final String? finalFile;
final String? logFile;
final String? outputFile;
final String? metaFile;
```

Parse snake/camel variants:

```dart
final_file / finalFile
log_file / logFile
output_file / outputFile
meta_file / metaFile
```

**Modify tests:** `test/services/hermes_manager/local_think_job_service_test.dart`

Add a row with those fields and assert they parse.

---

## Task 3 — Enrich local-think list rows with optional detail lookup

**Objective:** Since `hermes-local-think-ledger list --json` does not include final/artifact detail, add a bounded optional enrichment step for recent terminal jobs.

**Modify:** `lib/services/hermes_manager/local_think_job_service.dart`

Add dependency injection for detail lookup:

```dart
typedef LocalThinkLedgerDetailReader = Future<String> Function(String taskIdPrefix);
```

Constructor options:

```dart
LocalThinkJobService({
  LocalThinkLedgerReader? ledgerReader,
  LocalThinkLedgerDetailReader? detailReader,
  bool isWeb = kIsWeb,
  bool enrichDetails = false,
  int enrichLimit = 5,
})
```

Behavior:
- Default `enrichDetails = false` to preserve pass-1 behavior and avoid surprise process fanout.
- When enabled, call detail reader for at most `enrichLimit` most recent jobs.
- Merge fields from `show` JSON into the list-row job, especially `final_file`, `log_file`, `output_file`, `meta_file`, `context_from`, `started_at`.
- Do not read raw final/log file content in this pass. Only surface paths as artifacts.
- If detail lookup fails for one job, keep the list-row job and continue.

**Modify IO process file:** `lib/services/hermes_manager/local_think_ledger_process_io.dart`

Add:

```dart
Future<String> readLocalThinkLedgerDetailFromProcess(String taskIdPrefix) async {
  final result = await Process.run(
    'hermes-local-think-ledger',
    <String>['show', taskIdPrefix, '--json'],
  );
  ...
}
```

Also consider PATH risk: GUI apps may not inherit shell PATH. Keep the default command for now, but isolate it behind the process-reader function so a later settings/config pass can provide an absolute path.

**Modify tests:** `test/services/hermes_manager/local_think_job_service_test.dart`

Test:
- default does not call detail reader
- enrichment calls detail reader up to limit
- detail fields merge into jobs
- detail failure is non-fatal
- web guard still returns empty and does not call readers

---

## Task 4 — Map artifact paths into timeline events

**Objective:** Timeline cards should know where the final/log artifacts are, without showing raw logs.

**Modify:** `lib/services/hermes_manager/local_think_timeline_mapper.dart`

Rules:
- `artifactPath` should prefer `job.finalFile`, then `job.logFile`, then `job.outputFile`.
- Metadata may include artifact path keys, but `MainChatTimelineItem` must not display them by default.
- Keep `[SILENT]` behavior quiet.

**Modify tests:** `test/services/hermes_manager/local_think_timeline_mapper_test.dart`

Add assertion that `artifactPath` is populated from `finalFile`.

---

## Task 5 — Wire enriched local-think details conservatively

**Objective:** The main chat should show richer job cards without hammering the process layer.

**Modify:** `lib/screens/home/home_layout.dart`

Change the `_localThinkJobService` construction to enable bounded detail enrichment:

```dart
final LocalThinkJobService _localThinkJobService = LocalThinkJobService(
  enrichDetails: true,
  enrichLimit: 5,
);
```

Keep poll interval at 5s or increase to 10s if the UI feels noisy/heavy.

Important:
- Do not read raw final/log file content yet.
- Do not expose raw logs.
- Do not add cancel/retry buttons yet.

---

## Task 6 — Use `MainChatEventLog` in composer tests or home wiring only if low-risk

If low-risk, use `MainChatEventLog` inside `MainChatTimelineComposer` or `_ChatPaneState` to append composed events before rendering. If it complicates the current wiring, keep it tested but not wired yet. The important part is that the abstraction exists and is ready for persistence/sync.

---

## Verification

Run and fix:

```bash
/mnt/data/flutter-sdk/bin/flutter test test/models/main_chat_timeline_event_test.dart test/services/hermes_manager/local_think_job_service_test.dart test/services/hermes_manager/local_think_timeline_mapper_test.dart test/services/hermes_manager/main_chat_timeline_composer_test.dart test/services/hermes_manager/main_chat_event_log_test.dart test/widgets/hermes/main_chat_timeline_item_test.dart

/mnt/data/flutter-sdk/bin/flutter analyze lib/models/main_chat_timeline_event.dart lib/models/local_think_job.dart lib/services/hermes_manager/local_think_job_service.dart lib/services/hermes_manager/local_think_ledger_process_io.dart lib/services/hermes_manager/local_think_ledger_process_stub.dart lib/services/hermes_manager/local_think_timeline_mapper.dart lib/services/hermes_manager/main_chat_timeline_composer.dart lib/services/hermes_manager/main_chat_event_log.dart lib/widgets/hermes/main_chat_timeline_item.dart lib/screens/home/home_layout.dart

/mnt/data/flutter-sdk/bin/flutter build linux --debug
```

Manual/behavioral expectation:
- Normal chat still works.
- Local-think cards still appear inline in the main chat timeline.
- Cards have artifact paths in event data when detail enrichment succeeds.
- Raw artifact/log contents are not displayed by default.
- Web still does not try to run local processes.
- Process failures are swallowed into safe empty/partial state, not UI crashes.
