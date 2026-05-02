# Messages-to-visit workflow UX spec

Date: 2026-05-01
Issue: IMM-214

## Purpose

Define the operator-facing UX for the core messages-first leasing journey: inbox triage, lead qualification, visit booking, confirmations/reminders, and after-visit outcome handling.

The goal is a low-friction control surface Simon can use quickly without opening multiple admin screens to answer a simple question: what should I do with this conversation right now?

## Design goals

1. Reduce decision time
   - Every inbox item should tell the operator the next best action within a few seconds.
   - Avoid forcing the operator to open a lead, then a visit, then a separate report just to understand the status.

2. Keep the conversation primary
   - The UI should preserve the original message thread as the main source of truth.
   - Structured data should support the conversation, not replace it.

3. Make operational state visible
   - Operators need to see when a lead is waiting on qualification, waiting on availability, booked, awaiting confirmation, reminded, completed, or no-show.
   - The current state should be obvious in the inbox, detail view, and visit view.

4. Favor one deliberate action over many tiny edits
   - Default actions should be safe and fast.
   - Low-confidence classifications should ask for a single clear decision, not a form marathon.

5. Surface exceptions, not noise
   - The UI should highlight the conversations that need human judgment, while routine confirmed visits remain compact.

## Core object model in the UI

The operator mental model should be:

Message thread -> lead -> visit -> outcome

Each screen should present the same record through a different lens:

- Inbox: what needs attention now
- Lead detail: who this person is and whether they are qualified
- Visit detail: when the visit happens and what reminders were sent
- Outcome state: what happened after the visit

## Screen 1: Inbox triage

Primary goal: show the next action for each conversation.

Recommended row content:

- Lead name or clear placeholder if unknown
- Source channel badge, such as Messenger or SMS
- Property or building hint, if already known
- Current state badge
- One-line preview of the last message
- Timestamp of the last activity
- Risk / urgency indicator only when relevant

Recommended inbox buckets:

1. New inquiries
   - The conversation is waiting for first qualification.
   - Show a prominent “Qualify” action.

2. Awaiting missing detail
   - Ask for move-in date, number of occupants, budget, or preferred visit time.
   - Show the exact missing fields inline.

3. Visit candidate
   - The lead appears qualified and ready for scheduling.
   - Show a “Book visit” primary action.

4. Booked / awaiting confirmation
   - A visit exists but the lead has not yet confirmed or acknowledged.
   - Show a “Send confirmation” or “Resend reminder” action.

5. Confirmed upcoming visit
   - Keep this compact and low-noise.
   - Show only date, time, and confirmation status.

6. Post-visit follow-up
   - The visit is done and an outcome still needs recording.
   - Show a “Log outcome” action.

### Inbox interaction rules

- Clicking a row should open the thread context without losing the list position.
- The operator should always see the timeline of prior actions in the same view.
- If a lead is low confidence or ambiguous, the UI should ask one clarifying question at a time.
- Do not bury qualification behind a separate settings drawer.

### Inbox sorting priority

Sort by:

1. State urgency
2. Time since last inbound message
3. Upcoming visit time
4. Manual priority or SLA breach

The top of the inbox should be the conversations likely to stall revenue or create a no-show.

## Screen 2: Lead detail

Primary goal: let the operator decide whether this lead is worth a visit and what information is still missing.

Lead detail should include:

- Lead identity and contact information
- Source conversation history
- Qualification checklist
- Candidate property / unit context
- Suggested next action
- History of automated and manual messages

### Qualification checklist

Use a compact checklist, not a long form.

Suggested fields:

- Desired move-in date
- Occupancy count
- Budget / affordability fit
- Pet requirement
- Smoking requirement
- Relevant notes from the conversation

### Qualification states

1. Qualified
   - Lead matches basic criteria and can be offered a visit.
   - Make booking the primary action.

2. Needs more info
   - The lead is promising but incomplete.
   - Show the missing items as chips or short prompts.

3. Not a fit
   - The lead does not match basic requirements.
   - Allow a polite closeout and archive path.

4. Needs manual review
   - The bot is uncertain or the message contains conflicting details.
   - Escalate to Simon with the original text visible.

### Recommended actions

- Mark qualified
- Ask one missing question
- Offer visit times
- Close out as not a fit

Avoid presenting more than one primary action at a time.

## Screen 3: Visit booking

Primary goal: make scheduling feel fast and trustworthy.

Recommended booking flow:

1. Show available times
   - Present the next valid slots first.
   - Group by day and make the time zone explicit.

2. Confirm the chosen slot
   - Show building, unit, date, time, and visit method in one summary card.

3. Capture the booking result
   - Booked
   - Needs re-pick
   - No availability / offer alternate path

4. Send the visit confirmation immediately
   - The operator should not have to remember a second step.

### Booking UI rules

- Keep the time picker simple and mobile-friendly.
- Show conflicts before final commit.
- Make it obvious when employee availability is the limiting factor.
- Do not require the operator to jump to a separate calendar module to finish one booking.

### Booking summary card

Include:

- Building and unit
- Lead name
- Visit date and time
- Host / employee, if assigned
- Confirmation status
- Reminder schedule

## Screen 4: Confirmation and reminder states

Primary goal: make the communication lifecycle visible after booking.

The visit card should show a compact state ladder:

- Scheduled
- Confirmation sent
- Confirmed
- Reminder sent
- Visit day arrived
- Completed or no-show

### Recommended visibility

Each visit should display:

- Confirmation message sent time
- Reminder time(s)
- Delivery result, if available
- Last acknowledgment from the lead
- Whether a manual follow-up is still required

### Reminder UX

- Reminders should be explicit and minimal.
- When a reminder is sent, show the exact message content in collapsed form.
- If the reminder fails, surface the failure immediately instead of hiding it in logs.

### Failure handling

If confirmation or reminder delivery fails:

- show a visible warning badge
- offer resend
- expose the reason or fallback path
- preserve the booked visit state until an operator decides otherwise

## Screen 5: Visit outcome handling

Primary goal: make after-visit actions fast enough that the outcome actually gets recorded.

Recommended outcome states:

- Attended
- No-show
- Interested, follow up
- Not interested
- Apply next step / move to application
- Other / manual note

### Outcome UX rules

- The outcome should be one click or one short decision.
- Do not force operators through a long debrief form.
- If a visit is marked no-show or rescheduled, the next action should appear immediately.

### Outcome summary card

Include:

- Visit date/time
- Attendance status
- Operator note
- Next recommended action
- Follow-up timestamp

## Operational visibility requirements

The UI should make the funnel visible without turning into a dashboard-heavy product.

Required visible metrics:

- New inbound conversations
- Leads waiting for qualification
- Leads ready for booking
- Visits scheduled today / this week
- Confirmation completion rate
- Reminder delivery success
- Visit completion rate
- No-show rate
- Outcomes awaiting follow-up

### Where metrics should appear

- Inbox header: current queue pressure and urgent items
- Lead detail: state-specific completion indicators
- Visit detail: confirmation and reminder delivery status
- Lightweight summary strip: enough to understand health at a glance

Do not require the operator to open a separate analytics page to know whether the workflow is healthy.

## Copy guidance

User-facing strings should be short, practical, and action-oriented.

Examples:

- “Book visit” instead of “Schedule appointment”
- “Send confirmation” instead of “Trigger confirmation workflow”
- “Needs more info” instead of “Incomplete qualification state”
- “No-show” instead of “Did not attend scheduled visit”

Keep the language friendly and operator-focused, not bureaucratic.

## Recommended main-surface layout

The main operator surface should feel like one continuous workspace, not four separate modules.

Suggested layout:

1. Left rail: inbox queue
   - shows conversations sorted by urgency
   - keeps current stage badges visible at all times
   - supports quick filtering by source, state, assignee, and next action

2. Center panel: active thread and timeline
   - shows the original conversation, automated events, manual touches, and visit-related events in one timeline
   - preserves message order so the operator can reconstruct the conversation quickly
   - keeps the last unread or unresolved item anchored near the top

3. Right rail: next-action panel
   - changes based on the current stage
   - contains the single primary action, the key state summary, and the minimum needed scheduling controls
   - avoids turning the page into a full form unless the operator chooses to expand

### Primary action rules by stage

- New inquiry -> qualify or ask one missing question
- Needs more info -> ask the single highest-value missing question
- Visit candidate -> propose times and book a visit
- Booked / awaiting confirmation -> send confirmation or resend reminder
- Confirmed upcoming visit -> show schedule details only, with a light edit path
- Post-visit follow-up -> log outcome and next step

### State-to-visual mapping

The same state should look consistent everywhere:

- Inbox row: short badge + one-line next action
- Thread header: full state label + owner + next deadline
- Visit card: booking state + confirmation/reminder state + attendance state
- Outcome section: completion state + follow-up required or closed

### Empty and fallback states

- Empty inbox: show how many conversations are already handled and where to look next
- No candidate availability: say that explicitly and offer the fallback path, not an empty picker
- Missing lead identity: keep the thread actionable and let the operator qualify from the message content
- Delivery failure: surface the failure inline beside the confirmation or reminder that failed

### Operational visibility strip

A lightweight summary strip should appear above the workspace or inside the inbox header.

Recommended indicators:

- new inbound conversations
- conversations waiting on qualification
- qualified leads ready to book
- visits scheduled today and this week
- confirmations sent vs confirmed
- reminders sent and failed
- outcomes still waiting for follow-up
- conversations aging past the target response window

This strip is for fast health checks, not deep reporting.

## What not to build yet

- Full CRM-style reporting screens
- Deep analytics dashboards
- Multi-level approval flows
- A separate task manager for reminders
- Large configuration surfaces for every messaging rule

The first version should help Simon triage faster, book faster, and close the loop after the visit.

## Success criteria

This UX is good enough when Simon can answer the following from the main workflow surface alone:

1. Which conversations need action right now?
2. Which leads are qualified enough to book?
3. Which visit is scheduled next and who owns it?
4. Which visits still need confirmation or reminders?
5. Which completed visits still need an outcome recorded?

If those answers require multiple screens, the design is too heavy.
