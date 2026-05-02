# Renovation Ops Worker Phone / SMS / Photo Intake Workflow

## Purpose

Create one low-friction intake path for field workers so updates, photos, shortages, blockers, completion notes, and surplus notes all land in one operational memory tied to the apartment and the active renovation task.

This workflow is part of Renovation Ops, not Leasing. Leasing should only consume the resulting unit readiness state.

## Core worker message types

1. Update
   - Progress update on a task or apartment
   - Example: "Drywall finished in unit 402, paint tomorrow"

2. Missing material
   - A needed item is absent, damaged, incorrect, or too small
   - Example: "Need 2 more vanity anchors for 402"

3. Blocker
   - Work cannot continue until someone acts
   - Example: "Cannot start kitchen until old stove is removed"

4. Completion
   - A task, room, or apartment milestone is done
   - Example: "Bathroom demo complete, photos attached"

5. Surplus
   - Extra materials or reusable items remain after work
   - Example: "Left 6 unopened tiles in unit 402"

6. General note
   - Anything else that is useful but does not fit the above types
   - Example: site condition, access issue, trade note, timing note

## Minimum viable intake flow

### A. Text-only message

1. Inbound SMS lands on the central number.
2. System identifies worker identity from the phone number.
3. System tries to attach the message to the active apartment/task using:
   - explicit unit/apartment reference in text
   - recent active task for that worker
   - recent open renovation context for that apartment
4. System classifies the message into one of the core types.
5. System writes the raw message to the activity log and creates a structured intake record.
6. If confidence is high, the message is auto-linked and surfaced immediately.
7. If confidence is low, it goes to manual review.

### B. Photo-only message

1. Inbound MMS/photo lands on the central number.
2. System identifies worker identity from the phone number.
3. System stores the image(s) and original caption if present.
4. System attempts to infer context from the sender, timestamp, and active work order.
5. If a likely apartment/task is found, attach the photo there.
6. If no reliable context exists, queue for manual review.
7. Photo-only submissions should still be visible in the ops feed even before classification is complete.

### C. Text + photo message

1. Inbound SMS/MMS is received as one event.
2. System uses text for classification and context resolution.
3. System stores the photo(s) as evidence for the same intake record.
4. The structured record should preserve:
   - raw text
   - media URLs / attachments
   - sender identity
   - inferred apartment
   - inferred task
   - classification
   - confidence score

## Attachment rules

### Worker identity

- Primary identity key: phone number.
- Secondary identity data: worker profile, role, trade, company, and assignment history.
- If the phone number is unknown, create a review item instead of guessing a worker.

### Apartment identity

Attach to an apartment when one of these is true:
- the worker names the unit explicitly
- the worker is assigned to the current active apartment renovation
- the message matches a recent open task for that apartment
- the media or note clearly references the apartment context

### Task identity

Attach to the most specific task available when possible:
- a named task beats a generic apartment-level note
- a room-specific task beats a whole-unit task
- if the message is about multiple tasks, keep one parent intake record and link multiple tasks when supported

### Evidence linkage

- Every intake record should keep the original SMS/MMS payload.
- Photos are evidence, not just attachments.
- Multiple photos from the same message stay grouped together.
- If the message references materials or blockers, link them to the relevant order or inventory record when available.

## Phase 1 manual review rules

Manual review is required when any of the following apply:
- apartment or task cannot be identified with high confidence
- multiple apartments could match
- message is ambiguous between update, blocker, and missing material
- OCR or caption parsing is unclear
- phone number is unknown
- photo arrives without enough context
- a surplus note might actually be a return, damage report, or disposal issue
- completion claim conflicts with active task state

Manual review output should let an operator:
- confirm or change the message type
- assign apartment and task
- link the worker if needed
- mark the record as resolved
- add a follow-up action such as order creation or inventory adjustment

## What management should see in the global operations view

The global operations view should show Renovation Ops as a live control panel across all apartments.

### Top-level items
- inbound messages needing review
- open blockers
- missing material alerts
- recently completed tasks
- surplus items available for reuse
- apartments with no recent activity

### Each item should expose
- apartment/unit
- current task or phase
- worker name and phone
- message type
- timestamp
- latest photo thumbnail if present
- confidence / review status
- related order, receipt, or inventory link if available

### Management can act from the view
- open the apartment timeline
- acknowledge a blocker
- convert a missing-material note into an order request
- approve a completion note
- move surplus into reusable inventory
- send a follow-up SMS if clarification is needed

## Operational principles

- Keep the worker path as close to texting a person as possible.
- Do not require a heavy app for field reporting.
- Prefer one central operational inbox over scattered conversations.
- Preserve raw messages and media for auditability.
- Make low-confidence parsing explicit instead of silently guessing.
- Keep the Renovation Ops artifact separate from Leasing screens and workflows.

## Recommended v1 record shape

- messageId
- senderPhone
- workerId
- apartmentId
- taskId
- messageType
- rawText
- mediaUrls
- receivedAt
- confidence
- reviewStatus
- resolutionNotes
- relatedOrderId
- relatedInventoryItemId

## Outcome

This workflow gives Renovation Ops a single intake path for worker communication while keeping the data structured enough for operations, materials, and readiness tracking.
