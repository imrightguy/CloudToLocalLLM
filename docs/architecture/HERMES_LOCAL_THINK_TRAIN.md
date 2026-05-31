# Hermes Local-Think Train

Status: proposed companion surface for Hermes durable background work

## Why this exists

Telegram is Christopher's main text channel, but Telegram turns are request/response events. After a final reply, the foreground Hermes loop is not still running. Durable continuation needs explicit work sources: local systemd jobs, cron, webhooks, process completion callbacks, startup recovery, or kanban.

RIGHT-PC now has a local detached background lane:

- `~/.local/bin/hermes-local-think`
- `~/.local/bin/hermes-local-think-status`
- `~/.local/bin/hermes-local-think-ledger`
- SQLite ledger: `~/.hermes/local-think/jobs.db`
- artifacts: `~/.hermes/local-think/<task-id>.*`

CloudToLocalLLM can make that lane visible as a "thought train": a local companion panel showing what Hermes is doing in the background, what finished, what was skipped by wake gates, and which jobs are chained together.

Christopher's stronger product direction: the main window should not hide this in a secondary diagnostics page. It should become the primary cockpit: a permanent direct chat channel synced across devices through the Tailscale/private mesh, with the Hermes thought-train/activity stream and verbose tool/event log mixed into the same timeline in a controlled way.

## Current split

- Telegram: main text channel for Christopher-facing updates.
- Hermes foreground turn: immediate request/response tool use.
- `hermes-local-think`: bounded detached background reasoning or verification.
- Cron/webhooks/startup recovery: recurring/event-driven wake sources.
- CloudToLocalLLM: best candidate for a persistent visible desktop surface.

## What the thought train should show

Minimum useful panel:

- permanent direct chat timeline as the center of the main window
- synced across trusted devices over Tailscale/private mesh, not public cloud by default
- latest local-think jobs from `jobs.db`
- status: `queued`, `running`, `completed`, `failed`, `cancelled`, `skipped`
- name and task id
- attempts / max attempts
- dedup key when present
- parent task id / context-from lineage
- final answer preview from `.final.md`
- whether a result was `[SILENT]`
- verbose tool/event entries from Hermes: tool name, parameters summary, result summary, duration, artifact path
- collapsible raw logs; default collapsed to avoid overwhelming the chat
- last updated / finished time

Timeline layering:

1. User/assistant chat messages — always visible.
2. Thought-train summaries — visible inline as compact status cards.
3. Tool/event log — visible as expandable rows, with verbose mode toggle.
4. Raw tool output/logs — hidden until clicked.

This gives Christopher the sense that Hermes is continuously operating without pretending to expose raw hidden model chain-of-thought.
Useful controls later:

- open full final/log/artifacts
- cancel running job
- retry failed job
- queue a follow-up using `--context-from` and `--parent-task`
- toggle Telegram notification for a job

## Local data contract

SQLite path:

```text
~/.hermes/local-think/jobs.db
```

Primary table:

```sql
jobs(
  task_id text primary key,
  unit text,
  name text,
  status text,
  exit_code integer,
  attempts integer,
  max_attempts integer,
  dedup_key text,
  created_at text,
  started_at text,
  finished_at text,
  notify text,
  wake_gate text,
  prompt_file text,
  output_file text,
  final_file text,
  log_file text,
  meta_file text,
  runner_file text,
  parent_task_id text,
  context_from text,
  updated_at real,
  meta_json text
)
```

The UI should treat SQLite as the fast index and JSON/artifact files as the repair/source bundle. If a DB row points at a missing `meta_file`, show it as stale or hide it after a repair pass. The Flutter `LocalThinkJob` bridge intentionally preserves the full lightweight row contract needed by the surface (`unit`, `notify`, `wake_gate`, `runner_file`, `updated_at`, and `meta_json`) while keeping raw artifact contents behind explicit preview/expand actions. Detail enrichment must not rewrite the list row `task_id`; the ledger row remains the stable identity key even when `show --json` returns a mismatched or repaired detail payload.

Current low-risk bridge contract:

- ledger list payload may be either a raw JSON array or an object wrapper with `jobs: [...]`
- detail payload may arrive as the root object or under `job` / `task`; injected-service tests should keep all three shapes covered because the CLI bridge has already emitted multiple wrappers across iterations
- detail enrichment can update presentation fields such as `name`, `status`, lineage, and artifact paths, but not the stable ledger identity key; the Dart merge helper should preserve the original list-row `task_id` even when detail JSON reports a different prefix-matched task id
- missing/unreadable preview artifacts should drop only the preview text; they should not discard already-enriched detail fields such as `final_file`, `log_file`, or `meta_file`
- explicit `is_silent` / `isSilent` flags should win over preview sniffing and accept bool, numeric `1`/`0`, or trimmed string truthy values from ledger/detail JSON so quiet jobs stay visually recorded without being mislabeled as normal completions
- normalized preview text such as `Silent wake-gate skip.` must still preserve quiet-job state after `.final.md` preview enrichment, so the mixed timeline keeps silent iconography and low-noise labeling even when the raw `[SILENT]` marker is redacted away
- detail enrichment priority should fall back to ledger `updated_at` when `finished_at` / `started_at` / `created_at` are missing, so recently repaired terminal rows still get previews and lineage first
- timeline event timestamps should use the same `updated_at` fallback when explicit timestamps are missing, so repaired local-think rows do not sink to the oldest part of the mixed chat/activity stream
- cancelled jobs should stay visually distinct from failed jobs in the main timeline surface, even if both are terminal states
- `.final.md` preview reads stay opt-in, desktop-only, path-scoped, separator-normalized across Linux/Windows-style local paths, and redacted before showing inline in the main chat surface
- default preview path scope should resolve from the current desktop home environment (`HOME`, `USERPROFILE`, or `HOMEDRIVE` + `HOMEPATH`) instead of hardcoding a single machine-specific artifact root; tests should keep that scope overrideable

## Flutter implementation sketch

Suggested files:

- `lib/services/hermes_manager/local_think_job_service.dart`
- `lib/models/local_think_job.dart`
- `lib/widgets/hermes/local_think_train_card.dart` or `lib/widgets/hermes/main_chat_timeline_item.dart` for compact inline activity cards
- compact cards should prefer summary-first presentation, with metadata chips for timestamp and, in verbose/debug mode, task id, attempts, exit code when present, wake-gate/notify hints when useful, dedup key, and lineage
- current inline timeline item guardrails should stay implementation-aligned: compact mode shows only the safe summary/preview plus timestamp; verbose mode may reveal only curated metadata labels (task id, attempts, dedup, notify, wake gate, lineage, exit code), not arbitrary raw metadata blobs; artifact affordances should expose only a basename such as `job.final.md`, not the full local filesystem path, including Windows-style local paths; non-chat local-think/tool rows should not fall back to raw body text in compact mode when no safe summary exists
- tests under `test/services/hermes_manager/local_think_job_service_test.dart` and `test/widgets/hermes/main_chat_timeline_item_test.dart`

Service behavior:

- desktop-only; disabled on web
- poll every 2–5 seconds
- read SQLite via FFI if the app already has a local SQLite abstraction, or shell out to `hermes-local-think-ledger list --json` as a first low-risk bridge
- expose a small immutable snapshot/list to the UI
- never auto-launch jobs from the UI without explicit user action
- do not send Telegram notifications itself; local-think owns notification policy

Safer MVP bridge:

```text
CloudToLocalLLM -> hermes-local-think-ledger list --json -> LocalThinkJobService -> LocalThinkTrainCard
```

This avoids adding a second SQLite implementation path in Flutter before the UI is proven useful.

## Placement

Good first placement:

- main window home/chat surface as the default view, not a buried dashboard
- direct chat remains the spine of the UI
- thought-train cards appear inline between chat messages or in a right-side timeline rail
- verbose tool rows appear under the assistant turn or background job that caused them
- compact card above the input can show current active job / gateway state
- no demo controls by default

Avoid burying it only in the dashboard overview; Christopher may not see it during normal chat.

## Permanent synced chat channel

The main window should behave like a durable local-first chat channel rather than a disposable session view.

Recommended sync model:

- local append-only event log for chat messages, assistant replies, tool summaries, local-think job events, and delivery acknowledgements
- device sync over Tailscale/private mesh first
- each device keeps a local copy and reconciles by monotonic event ids / timestamps
- Hermes gateway/Telegram remains the external text bridge; CloudToLocalLLM is the local desktop/mobile cockpit
- message/event payloads should be encrypted at rest and in transit when leaving localhost
- if Tailscale is offline, queue locally and reconcile later

Do not make public cloud the required path for private chat continuity. Cloud can be optional relay/bootstrap, not the source of truth.

## Guardrails

- Do not expose raw prompt/log content by default; logs can contain private context.
- Show previews and status first, full artifacts only on explicit click.
- Keep Telegram as the main text update channel.
- Keep local-think low-noise: `[SILENT]` jobs should be visually recorded but not pushed.
- Wake gates should prevent curiosity loops from spending tokens while gateway/local-think is busy.
- Background thought train is not chain-of-thought disclosure. It should show task state, decisions, summaries, and artifacts — not hidden model reasoning.
- Label it as "activity", "tool trace", "work train", or "thought train summaries" in developer docs; in UI avoid implying raw private reasoning is exposed.
- Verbose mode should be user-toggleable and scoped: compact by default, expanded when debugging.
- Tool calls that touch secrets, personal files, or tokens must be redacted/summarized before appearing in the main timeline.

## Next safe code slice

1. Add `LocalThinkJob` model with JSON parsing from `hermes-local-think-ledger list --json`.
2. Add `LocalThinkJobService` that shells out to the ledger command on desktop only.
3. Add tests using injected command output, not real `~/.hermes`.
4. Add `LocalThinkTrainCard` with a compact list and final preview.
5. Wire the card into `home_layout.dart` near `_RuntimeChannelHeader` with a conservative desktop-only guard.
6. Add a second design/code slice for the permanent synced chat event log: `ChatTimelineEvent` model, local append-only storage, and Tailscale sync abstraction.
7. Only after the event log exists, merge chat messages + local-think events + verbose tool rows into one main-window timeline.

## Verification

- `flutter test test/services/hermes_manager/local_think_job_service_test.dart`
- `flutter analyze lib/services/hermes_manager/local_think_job_service.dart lib/widgets/hermes/local_think_train_card.dart lib/screens/home/home_layout.dart`
- if UI wiring changes: `flutter build linux --debug`

## Bottom line

Yes: CloudToLocalLLM is probably the better place for the visible "train of thoughts" surface, as long as "thoughts" means durable job/status summaries, not raw hidden chain-of-thought. Hermes should keep doing background work through explicit durable lanes; CloudToLocalLLM should make that work visible, inspectable, and controllable on the desktop.
