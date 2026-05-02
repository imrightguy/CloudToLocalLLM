# Marketplace inbox and visit scheduling interaction design

Date: 2026-05-01
Issue: IMM-219

## Purpose

Define the interaction model for the messages-first Marketplace lane so Simon can triage conversations, move qualified leads into visits, and keep confirmations/reminders visible without losing thread context.

This is intentionally not a broad CRM spec. It is the minimum interaction model for:

- inbox triage
- thread state awareness
- action affordances
- visit scheduling
- confirmation and reminder visibility

## Interaction principles

1. Keep the thread centered
   - The message thread is the primary canvas.
   - State badges and actions should support the thread, not replace it.

2. One screen, one decision
   - The operator should know what to do next without hopping between modules.
   - If the system can suggest a single next action, it should do so.

3. Make transitions explicit
   - When a thread moves from inquiry to qualified to booked, the UI should show that change clearly.
   - A visit should never feel like a hidden side effect.

4. Keep confirmations visible
   - Booked visits must remain easy to see until they are confirmed and attended.
   - Reminders and failures should be visible in the same place as the visit.

5. Prefer compact controls
   - Use short action buttons, chips, and state pills.
   - Avoid large forms for common path actions.

## Screen 1: Inbox triage

Primary job: identify which threads need attention now.

### Inbox row anatomy

Each row should show:

- lead name or placeholder if unknown
- channel badge, such as Marketplace or SMS
- thread state badge
- short message preview
- last activity time
- urgency marker only when needed
- visit date/time if already booked

### Recommended states

- New inquiry
- Needs qualification
- Ready to book
- Visit pending confirmation
- Confirmed visit
- Needs reminder resend
- Post-visit follow-up
- Closed

### Inbox behavior

- Clicking a row opens the full thread in place or in a persistent detail panel.
- The current list position should stay intact when the operator closes the detail panel.
- The top of the list should privilege state urgency before raw recency.
- Booked visits coming up soon should remain visible even if the last message is old.

### Suggested primary action per state

- New inquiry → Qualify
- Needs qualification → Ask missing question
- Ready to book → Book visit
- Visit pending confirmation → Send confirmation
- Confirmed visit → Send reminder
- Post-visit follow-up → Log outcome

## Screen 2: Thread detail

Primary job: let the operator understand the conversation and move it forward.

### Thread layout

Top area:

- lead identity
- current state pill
- next suggested action
- visit summary if one exists

Main area:

- chronological message history
- system events such as qualification, booking, confirmation, reminder, outcome
- attachments or supporting context if available

Right rail or lower summary area:

- qualification facts
- visit slot
- assigned employee
- communication status

### Thread state presentation

The state should always be visible near the top of the thread.

State should explain:

- what has already happened
- what is waiting
- what the operator can do next

### Interaction rules

- The operator should never need to open a separate visit screen just to know whether a visit is booked.
- If the thread is ambiguous, show the original inbound message plus a short explanation of what is missing.
- If automation already advanced the thread, keep the manual action buttons visible but secondary.

## Screen 3: Qualification and handoff

Primary job: turn an inbound lead into a schedulable visit.

### Qualification affordances

Use lightweight controls for the common qualification questions:

- move-in timing
- budget fit
- occupancy count
- pet requirement
- smoking requirement
- preferred visit window

### Handoff states

- Qualified and bookable
- Needs one more answer
- Not a fit
- Needs human review

### Handoff rules

- If all core fields are present, booking should be the default action.
- If one field is missing, ask only for that field.
- If the lead is not a fit, close out politely and stop escalating.
- If confidence is low, preserve the thread and escalate to Simon with the raw message visible.

## Screen 4: Visit scheduling

Primary job: convert a qualified lead into a concrete visit slot.

### Scheduling flow

1. Show available times
   - Prefer the next valid slots first.
   - Group slots by day.
   - Show the host or employee if the visit depends on staffing.

2. Confirm the selected slot
   - Display building, unit, date, time, and host in one compact summary.

3. Commit the booking
   - Once committed, the visit should appear in the thread state immediately.
   - Do not hide booking behind a separate calendar page.

4. Send confirmation
   - Confirmation should be the natural next step after booking.
   - If confirmation can fail, surface that failure in the same view.

### Scheduling rules

- Show conflicts before commit, not after.
- Make timezone and day-of-week explicit.
- If no slot works, show alternate next-best options instead of leaving the operator stuck.
- Booking should be possible in one quick decision path, not a multi-step wizard.

### Scheduling summary card

Include:

- unit or building
- lead name
- visit date and time
- host / employee
- confirmation status
- reminder plan

## Screen 5: Confirmation and reminders

Primary job: keep the operator aware of communication state after a visit is booked.

### State ladder

- Scheduled
- Confirmation sent
- Confirmed
- Reminder sent
- Reminder failed
- Visit day arrived
- Completed
- No-show

### Visibility rules

- Each booked visit should show the last confirmation and reminder timestamp.
- Delivery failures should be visible immediately, not hidden inside logs.
- Resend should be available from the same place as the failure.
- If a lead confirms manually, the UI should reflect that without requiring a background log hunt.

### Reminder control rules

- Reminders should be actionable from the visit card.
- The operator should be able to resend or adjust a reminder without leaving the thread.
- The system should not generate repetitive nudges unless the visit is approaching.

## Screen 6: Post-visit outcome

Primary job: capture what happened quickly enough that the workflow stays current.

### Outcome options

- Attended
- No-show
- Interested, follow up
- Not interested
- Proceed to application
- Reschedule
- Other / note

### Outcome interaction rules

- Outcome should be one direct action, not a long form.
- If a visit is marked no-show, show the follow-up action immediately.
- If the lead is ready for the next stage, make that next stage visible in the same view.

### Outcome summary card

Include:

- visit time
- attendance status
- operator note
- next action
- follow-up requirement

## Visual language

Use a simple visual hierarchy:

- strong state pill at the top
- primary action button immediately near the thread header
- secondary actions collapsed behind a compact menu
- warnings only for meaningful failures

The interface should feel like a command surface, not a dashboard collage.

## Suggested copy style

Keep labels short and direct.

Preferred examples:

- Qualify
- Book visit
- Send confirmation
- Send reminder
- Log outcome
- Needs more info
- Ready to book
- Reminder failed

Avoid verbose internal language such as:

- execute booking workflow
- initiate confirmation dispatch
- update conversation lifecycle status

## Operational visibility

Without adding a separate analytics product, the surface should still expose:

- number of threads needing qualification
- number of threads ready to book
- visits booked today
- confirmations pending
- reminders failed
- outcomes waiting to be logged

These indicators should appear where Simon is already working, not in a separate reporting island.

## What to avoid

- Separate inbox and visit systems that duplicate state
- Deep settings pages for the common workflow
- A long multi-screen booking wizard
- Generic CRM abstractions that hide the conversation
- Silent state changes that the operator cannot see

## Success criteria

This interaction model is good enough when Simon can:

1. open an inbound conversation and immediately know the next action
2. qualify a lead without leaving the thread
3. book a visit and confirm it from the same surface
4. see whether reminders were sent or failed
5. record the visit outcome without losing the conversation context

If any of those steps require a detour, the design is too heavy.
