# SMS/MMS intake infrastructure path

Date: 2026-05-01
Issue: IMM-182

## Purpose

Define the execution-ready infrastructure path for Renovation Ops worker intake so inbound SMS/MMS can land as structured, auditable records with media preserved, low-confidence cases routed for review, and no leakage into Leasing workflows.

This plan is intentionally narrow: it covers the intake plumbing, not the full Renovation Ops UI or downstream workflow automation.

## Current state discovered in code

The backend already has a Twilio-oriented SMS stack:

- `services/api-backend/src/controllers/sms-webhook.controller.js`
- `services/api-backend/src/routes/sms.routes.js`
- `services/api-backend/src/services/sms.service.js`
- `services/api-backend/src/services/twilio.service.js`
- `services/api-backend/src/config/validation-schemas.js`
- `services/api-backend/src/database/schema.js`

What exists now:

- inbound SMS webhook route
- Twilio delivery-status webhook route
- Twilio send helper
- SMS log table for outbound/inbound tracking
- JSON validation for the current text-only inbound payload

What is missing for Renovation Ops intake:

- media-aware webhook parsing
- raw payload persistence for auditability
- attachment storage/linking path
- a dedicated intake record shape for worker updates
- explicit review-state handling for low-confidence parsing
- infrastructure/config checklist for Twilio media callbacks and base URLs

## Target outcome

A worker texting the central number can send:

- text-only updates
- photos with captions
- text + photo together

The system should then:

1. capture the raw webhook payload
2. identify or defer worker identity by phone number
3. preserve media URLs and message metadata
4. create a structured intake record
5. route low-confidence messages to manual review
6. keep the data available for the Renovation Ops dashboard and readiness workflows

## Recommended execution slices

### Slice 1 — webhook contract hardening

Deliverables:

- extend inbound SMS validation to accept Twilio MMS fields:
  - `NumMedia`
  - `MediaUrl0..n`
  - `MediaContentType0..n`
  - `SmsMessageSid` / message metadata if present
- normalize inbound payloads into one internal shape
- keep the current Twilio 200-response behavior so retries do not explode

Acceptance:

- inbound SMS still works
- inbound MMS no longer fails validation
- a raw payload object can be reconstructed from the inbound request

### Slice 2 — persistent intake record shape

Deliverables:

- add a database-backed record for worker intake events, or extend the current communication log path with Renovation Ops-specific metadata
- persist:
  - sender phone
  - raw text
  - media URLs
  - inferred apartment/task ids when known
  - classification
  - confidence
  - review status
  - original Twilio payload
- preserve a stable audit trail for operator review

Acceptance:

- every inbound message creates one durable record
- photos remain linked to the original message
- low-confidence messages can be reviewed later without losing raw data

### Slice 3 — media handling infrastructure

Deliverables:

- define where media is stored or referenced
- make storage strategy explicit:
  - reference Twilio-hosted URLs only for v1, or
  - copy into durable object storage if required for retention
- ensure the intake record keeps all media references together
- document retention expectations and failure behavior

Acceptance:

- photo-only messages are visible as intake items
- multiple photos from one message stay grouped
- storage choice is documented and implementable

### Slice 4 — operational config and environment requirements

Deliverables:

- document required Twilio env vars and webhook URLs
- document public base URL requirements for webhook reachability
- document local dev behavior when Twilio is unavailable
- document production observability requirements for intake failures

Acceptance:

- a deployer can configure the intake path without guessing
- local dev and prod use the same route contract
- webhook URLs are clear and unambiguous

## Suggested implementation order

1. harden webhook payload validation
2. define the intake record schema
3. wire raw payload + media persistence
4. add manual-review state fields
5. document environment and webhook setup

## Open decisions

These should be settled before deeper UI work:

- Do we keep media URLs only, or copy media into our own storage?
- Do we create a new `worker_intake` table, or extend an existing communication table?
- What is the minimum classification taxonomy for v1?
- Which fields are required for manual review in the ops dashboard?

## Immediate next implementation tickets

1. Inbound SMS/MMS webhook contract update
2. Worker intake persistence model
3. Media attachment storage strategy
4. Manual review queue API contract
5. Renovation Ops ops-feed summary endpoint

## Definition of done for this infra path

This issue can be considered satisfied once at least one of the following is true:

- the plan above is converted into execution-ready child issues, or
- Slice 1 + Slice 2 are implemented with tests, or
- a blocker is documented with exact proof and ownership if the storage/config path cannot be finalized yet

## Boundary reminder

This work belongs to Renovation Ops, not Leasing.
Leasing should only consume readiness state after the intake/workflow layer is in place.
