# Messages-first lane sequencing and operating metrics

Date: 2026-05-01
Issue: IMM-216

## Purpose

Define the immediate execution order for the active messages-first lane and the smallest useful set of operating metrics that tell us whether Marketplace inbox handling is converting into scheduled visits.

This plan stays narrow: it focuses on Marketplace inbox intake, follow-up, booking, visit outcomes, and the dashboards needed to see whether the lane is moving.

## Lane scope

In scope for this execution wave:

- Marketplace inbox monitoring and reply handling
- lead qualification from inbound messages
- visit scheduling and confirmation
- reminder and reschedule follow-up
- visit outcome capture
- basic reporting on inbox-to-visit flow

Out of scope for this lane:

- renovation execution
- lease administration
- rent collection
- renewal workflows
- broad CRM cleanup not tied to a booking or visit

## Recommended execution sequence

### Slice 1 — inbox intake and triage

Goal: make sure every Marketplace message enters a visible, actionable pipeline.

Deliverables:

- a clear inbox queue for new inbound conversations
- a triage state for conversations needing immediate response
- assignment rules for who owns first reply and follow-up
- audit trail for when the conversation was first seen and first answered

Acceptance:

- no inbound Marketplace conversation can sit unowned
- we can measure first-response delay from the moment it lands
- triage states are visible to operators

### Slice 2 — qualification and booking

Goal: convert qualified conversations into scheduled visits without losing context.

Deliverables:

- qualification outcome per conversation
- booking state tied to the visit request
- booking timestamp and source conversation linkage
- clear path for reschedule or rejection reasons

Acceptance:

- a qualified conversation can be booked into a visit
- booking is traceable back to the originating inbox thread
- rejected or unqualified conversations still retain reason codes

### Slice 3 — visit confirmation and reminders

Goal: reduce drop-off after booking.

Deliverables:

- confirmation state for booked visits
- reminder timing for upcoming visits
- reschedule / no-response handling
- visibility into whether confirmation was sent and acknowledged

Acceptance:

- every booked visit has a confirmation status
- reminder activity is visible
- missed confirmation becomes measurable instead of silent

### Slice 4 — visit outcome tracking

Goal: make the post-visit outcome visible so the lane does not end at the calendar entry.

Deliverables:

- visit outcome states such as completed, no-show, rescheduled, cancelled
- outcome capture timestamp
- reason codes for failed visits
- linkage from outcome back to lead and source conversation

Acceptance:

- every visit has an outcome state or is explicitly marked pending
- no-show rate can be calculated
- outcome visibility is available without manual reconstruction

### Slice 5 — reporting and dashboard

Goal: expose the simplest possible dashboard that answers whether the lane is working.

Deliverables:

- daily summary of inbox volume, replies, bookings, completed visits, and no-shows
- weekly trend view for conversion and latency
- operator-facing view of stalled conversations and unclosed outcomes
- metric definitions published alongside the dashboard

Acceptance:

- operators can tell if the lane is healthy in under a minute
- management can see conversion and bottlenecks without digging through logs

## Immediate operating metrics

These are the first metrics that matter for the lane.

### 1. Inbox-to-visit throughput

Definition:

- booked visits / inbound Marketplace conversations

Why it matters:

- tells us whether inbox activity is turning into real visit volume

What to slice by:

- source channel
- building or listing
- operator
- day of week

### 2. Follow-up latency

Definition:

- time from inbound message to first human response

Recommended views:

- median follow-up latency
- 95th percentile follow-up latency
- percentage answered within the business-hours target window

Why it matters:

- slow first reply is the easiest way to lose a visit

### 3. Booking conversion

Definition:

- qualified conversations that become booked visits / qualified conversations

Why it matters:

- shows whether qualification and closing are working, not just whether people are messaging us

### 4. Visit outcome visibility

Definition:

- visits with a captured outcome / total booked visits

Recommended companion view:

- percentage of visits still pending outcome after 24 hours

Why it matters:

- if outcomes are missing, we cannot learn from no-shows or completed visits

## Operational dashboard questions

The lane dashboard should answer these questions first:

- How many new Marketplace conversations arrived today?
- How many received a first reply?
- How many were qualified?
- How many were booked into visits?
- How many visits completed, no-showed, or were rescheduled?
- Which conversations are stalled and need attention now?

## Suggested owner split

- Inbox ownership and SLA: Operations / messaging owner
- Booking and calendar flow: Backend + product coordination
- Reminder / follow-up automation: Backend engineer
- Metrics and dashboard presentation: Frontend / analytics engineer
- Lane coordination and prioritization: CTO / operator lead

## Immediate next tickets

1. Inbox queue and first-response tracking
2. Qualification and booking state model
3. Visit confirmation and reminder instrumentation
4. Visit outcome capture and reason codes
5. Metrics dashboard for inbox-to-visit flow

## Definition of done for this issue

This issue is satisfied when at least one of the following is true:

- the lane sequence above is converted into child execution tickets, or
- the first slice is implemented with measurable first-response tracking, or
- the metrics definitions are published and tied to a working dashboard / report

## Boundary reminder

This lane is about turning messages into visits.
Anything that does not move inbox conversations toward a booked or completed visit should stay out of scope for this wave.
