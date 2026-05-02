# Renovation Ops dashboard and worker-intake review UX spec

Date: 2026-05-01
Issue: IMM-181

## Purpose

Define the operator-facing UX for Renovation Ops so the team can see what needs attention first, drill into a unit quickly, and triage worker messages without adding friction to field reporting.

This spec intentionally stays inside Renovation Ops. It does not introduce Leasing screens beyond the readiness bridge defined in the boundary doc.

## UX principles

1. Summaries first, detail on demand
   - The dashboard should answer: what is blocked, what needs review, what changed recently, and what can be reused.
   - Unit detail should open only after an operator chooses a specific apartment.

2. Keep worker input as close to texting as possible
   - Workers should send a short message, optionally attach photos, and stop there.
   - Any interpretation, classification, or routing complexity belongs on the operator side.

3. Make uncertainty visible
   - If a message parse is low-confidence, the queue should say so explicitly.
   - Operators should be able to recover the original text/photo payload instantly.

4. Tie every actionable item back to an apartment
   - Dashboard rows, review items, blockers, and photos should all land in the apartment narrative.
   - The UI should never feel like a generic inbox.

## Screen 1: Global operations dashboard

Primary goal: show the few things that require intervention right now.

Recommended layout order:

1. Review queue header
   - Count of messages needing review
   - Count of blocked apartments
   - Count of open missing-material items
   - Count of available surplus items

2. Messages needing review panel
   - Highest priority panel, always above the fold
   - Sorted by confidence, recency, and severity
   - Each row should show:
     - apartment identifier
     - worker name or phone
     - inferred category
     - confidence indicator
     - photo count
     - timestamp
   - Row click opens the review drawer

3. Open blockers and missing-material panel
   - One row per apartment or active blocker thread
   - Highlight blocking reason in plain language
   - Show whether the blocker is waiting on materials, access, inspection, or worker follow-up
   - Include a direct jump to the apartment drill-down

4. Recently completed panel
   - Show only the last meaningful completions, not a full history feed
   - Focus on units that just moved forward, so management sees momentum

5. Surplus available-for-reuse panel
   - Show reusable items by apartment and material type
   - Make the source apartment visible so operators do not lose context

6. Apartment search / drill-down entry
   - Search by unit number, building, or worker thread origin
   - Keep it lightweight; this is a control surface, not a reporting tool

### Dashboard interaction rules

- Clicking a review item should open a side drawer, not navigate away.
- Clicking an apartment should open a persistent drill-down panel with the current cycle context.
- The dashboard should retain the current scroll state after closing a drawer.
- Avoid nested tabs unless they materially reduce clutter.

## Screen 2: Apartment drill-down

Primary goal: give the operator one coherent renovation narrative for a unit.

Recommended top section:

- unit identifier and current readiness state
- active blockers summary
- latest worker update summary
- task completion status
- open material needs
- last photo update time

Recommended content order:

1. Timeline
   - chronologically ordered activity log
   - worker updates, photo uploads, review decisions, blocker changes, receipts, and completions

2. Open tasks
   - status, assignee, due date, and short notes
   - quick action for marking blocked or completed

3. Materials and orders
   - outstanding orders
   - partial receipts
   - shortages tied to this unit

4. Photos and evidence
   - newest photos first
   - thumbnails should be visible inline
   - clicking a photo should enlarge without leaving the unit

5. Readiness bridge summary
   - show the leasing-facing readiness state as a compact read-only badge only

### Drill-down behavior

- The operator should not need to switch between separate task, material, and photo screens to understand one apartment.
- All records should feel attached to the same apartment story.
- If the apartment is blocked, the blocking reason should stay pinned near the top while scrolling.

## Screen 3: Worker message review drawer

Primary goal: let an operator classify a worker message in one pass.

Drawer contents:

- original message text
- sender identity and phone number
- inferred apartment, if any
- inferred category
- confidence score or confidence band
- attached photos
- raw payload metadata link

Recommended review actions:

- confirm suggested category
- reclassify to another category
- attach to a different apartment or task
- mark as blocker
- mark as missing material
- mark as completion
- mark as surplus
- send a short reply if clarification is needed
- dismiss as general note if it is not operationally actionable

### Review drawer behavior

- Default action should match the model suggestion when confidence is high.
- Low-confidence items should require one deliberate confirmation, not a multi-step form.
- Photos should be visible before the operator commits the classification.
- If a message contains both text and photos, keep them in one unified review surface.

## Worker-side intake design constraints

Workers should see the lowest-friction possible intake experience:

- one phone number
- short text first
- optional photos
- no login
- no forms
- no branching workflow

Suggested message pattern for workers:

- update: "Finished patching the kitchen wall"
- missing material: "Need 2 more boxes of tile"
- blocker: "Cannot enter unit until noon"
- completion: "Room 3 done"
- surplus: "Left 1 unopened paint can"

The operator UI, not the worker, should normalize these into structured records.

## Photo visibility rules

- Photos are evidence, not an attachment afterthought.
- Every message with photos should show thumbnails in both the review queue and the apartment timeline.
- If a message is classified as a blocker or missing-material report, photos should remain directly adjacent to the classification.
- Photos should be sortable by recency inside the apartment drill-down.

## Empty and fallback states

- Empty dashboard: show the next expected operational action, not a blank analytics page.
- Empty review queue: confirm that nothing needs triage and point to blockers or recent completions.
- No photos: show the text payload clearly and do not reserve large empty photo space.
- Unknown apartment: keep the message in review and surface the unresolved unit lookup instead of dropping it.

## Execution-ready subtasks implied by this spec

1. Build the dashboard shell with the five priority panels above.
2. Build the review drawer with suggested classification, photos, and quick triage actions.
3. Build the apartment drill-down with timeline, tasks, materials, and photo evidence in one place.
4. Add pinned blocker state handling so operators never lose the reason a unit is stuck.
5. Ensure the worker intake surface stays SMS/MMS-first and does not add form friction.

## Success criteria

The UX is good enough when an operator can:

- identify the most urgent issue in under 10 seconds
- review and classify a worker message in one pass
- open a unit and understand its blocker, latest update, and evidence without leaving the screen
- keep worker reporting simple enough that the field flow still feels like sending a text

## Boundary reminder

Renovation Ops owns physical readiness work, field updates, blockers, materials, receiving, and surplus reuse. Leasing only consumes readiness state and must not inherit the operational dashboard or the worker review experience.
