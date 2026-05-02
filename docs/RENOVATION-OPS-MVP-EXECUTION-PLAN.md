# Renovation Ops MVP Execution Plan

## Purpose

Turn the approved Renovation Ops direction into executable Paperclip work without drifting into Leasing.

This plan covers the MVP scope:
- apartment renovation record
- task tracking by apartment
- order tracking linked to apartment and task
- receiving / partial receiving
- surplus inventory
- global operations dashboard
- worker phone / SMS / photo intake

## Ownership model

Recommended owner roles:

- Product / boundary: CEO
- Data model / backend APIs: Backend Engineer
- Worker intake / SMS / MMS / integrations: Integrations Engineer
- Operations dashboard / UI: Frontend Engineer
- Reporting / visibility / cross-module handoff: Product + Backend jointly

## Execution epics

### Epic 1: Renovation Ops module boundary and core record model

Goal: define the standalone module, the entities it owns, and the contract with Leasing.

Child issues:
- Finalize Renovation Ops charter and non-goals
- Define apartment readiness lifecycle and handoff contract to Leasing
- Define core entities: renovation record, task, order, receiving event, surplus inventory item, worker intake record
- Specify status model and transition rules

Owner recommendation:
- CEO + Backend Engineer

Dependency notes:
- All later implementation work depends on this epic.
- Leasing should only consume readiness state, never renovation detail screens.

### Epic 2: Apartment renovation record and task tracking

Goal: track one renovation narrative per apartment and break work into actionable tasks.

Child issues:
- Apartment renovation record CRUD
- Task list per apartment with statuses, assignees, due dates, and notes
- Task timeline / activity log
- Completion and blocker annotations

Owner recommendation:
- Backend Engineer + Frontend Engineer

Dependency notes:
- Depends on Epic 1 entity definitions.
- Worker intake should be able to attach to tasks from this epic.

### Epic 3: Order tracking, receiving, partial receiving, and surplus inventory

Goal: make materials visible from request to receipt to reuse.

Child issues:
- Order record linked to apartment and optionally task
- Receiving event model for full and partial receipts
- Surplus inventory item model and reuse state
- Material shortage / blocker linkage to orders
- Inventory-to-task traceability

Owner recommendation:
- Backend Engineer + Integrations Engineer

Dependency notes:
- Receiving and surplus flows depend on the apartment/task model.
- Worker messages about shortages and surplus should attach to these records when possible.

### Epic 4: Worker phone / SMS / photo intake

Goal: let workers report progress by texting one central number.

Child issues:
- Inbound SMS/MMS webhook intake
- Worker identity resolution by phone number
- Message classification: update, missing material, blocker, completion, surplus, general note
- Photo storage and attachment to intake records
- Manual review queue for low-confidence parsing

Owner recommendation:
- Integrations Engineer + Backend Engineer

Dependency notes:
- Needs the core apartment/task model.
- Should preserve raw payloads for auditability.
- Parsing confidence must be visible to operators.

### Epic 5: Global operations dashboard

Goal: give management one live view of work across apartments.

Child issues:
- Dashboard queue for messages needing review
- Open blockers and missing-material panels
- Recently completed tasks panel
- Surplus available-for-reuse panel
- Apartment timeline / drill-down view

Owner recommendation:
- Frontend Engineer + Product

Dependency notes:
- Depends on Epic 2, 3, and 4 data being available.
- Dashboard should show summaries first and drill down only when requested.

### Epic 6: Cross-module readiness handoff to Leasing

Goal: expose only the readiness signal that Leasing needs.

Child issues:
- Define ready-to-list / ready / leased status bridge
- Ensure Leasing consumes only readiness state
- Prevent renovation details from leaking into Leasing screens
- Validate handoff transitions and failure states

Owner recommendation:
- CEO + Backend Engineer

Dependency notes:
- Depends on Epic 1 lifecycle decisions.
- This is a boundary enforcement epic, not a Leasing feature build.

## Recommended order of execution

1. Epic 1: module boundary and core record model
2. Epic 6: readiness handoff contract, if needed to unblock downstream assumptions
3. Epic 2: renovation record and task tracking
4. Epic 3: orders, receiving, partial receiving, surplus inventory
5. Epic 4: worker intake and photo ingestion
6. Epic 5: global operations dashboard

Why this order:
- product/data decisions come first
- implementation agents need stable entities before UI work
- worker intake and inventory work depend on the shared record model
- the dashboard should be built last so it reflects settled workflows

## Explicit dependency notes

- Do not build standalone Leasing renovation screens.
- Do not mix renovation task state with lead/visit state.
- Do not hide worker messages inside generic notes if they are actionable.
- Do not require photo uploads to be tied to a heavy app flow.
- Do not allow surplus inventory to be treated as generic stock without apartment context.
- Do not let the dashboard become a generic analytics page; it should be an operational control surface.

## Suggested child issue breakdown

For Paperclip execution, the following issue types are the cleanest split:

- Product definition
  - module charter
  - readiness lifecycle
  - entity definitions
  - non-goals

- Backend / data model
  - schemas and migrations
  - API routes
  - workflow state transitions
  - audit/activity logging

- Integrations
  - SMS/MMS intake
  - media attachment handling
  - classification and confidence scoring
  - manual review queue hooks

- Frontend
  - dashboard queue
  - apartment timeline
  - task detail
  - review actions

## Final boundary summary for downstream agents

Renovation Ops is a standalone module that owns apartment turnover work, field updates, materials, blockers, receiving, and surplus reuse. Leasing only consumes the unit readiness state and must not absorb renovation workflow detail.
