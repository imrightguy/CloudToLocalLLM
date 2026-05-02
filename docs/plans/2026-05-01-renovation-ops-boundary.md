# Renovation Ops module boundary and technical contract

Date: 2026-05-01
Issue: IMM-178

## Final module charter

Renovation Ops is a standalone ImmoGestion module for post-lease turnover and apartment readiness execution. It owns the operational work required to move a unit from vacant to ready-for-leasing:

- apartment turnover tracking
- renovation and punch-list tasks
- worker coordination and assignments
- field photo updates and progress evidence
- missing-material reports and blocker tracking
- order tracking and receiving
- surplus inventory handling
- unit readiness status and handoff to Leasing

Renovation Ops is not a leasing feature. It is the execution layer for preparing units.

## Explicit non-goals

Renovation Ops does not own:

- listings or listing publishing
- lead intake or lead qualification
- visit scheduling or showing coordination
- applications, screening, or lease signing
- pre-move tenant communications
- rent collection, renewals, or tenant lifecycle management
- general CRM workflows unrelated to physical apartment readiness

The only bridge to Leasing is unit readiness status. Leasing may consume readiness, but it should not absorb Renovation Ops workflows.

## Canonical entity graph

The module should be modeled around one renovation cycle per apartment/unit, with all operational records hanging off that cycle.

Recommended core entities:

| Entity | Owns | Key relationships |
| --- | --- | --- |
| `renovation_cycles` | one turnover lifecycle for a unit | belongs to one `unit_id`; has many tasks, orders, receiving events, surplus items, and intake records |
| `renovation_tasks` | actionable work items | belongs to one `renovation_cycle_id`; may be room-scoped and worker-assigned |
| `renovation_orders` | material requests and purchases | belongs to one `renovation_cycle_id`; may optionally reference one `task_id` |
| `receiving_events` | full or partial material receipt events | belongs to one `renovation_order_id` |
| `surplus_items` | reusable leftover materials | belongs to one `renovation_cycle_id` and may reference a receiving event |
| `worker_intake_records` | inbound SMS/MMS/photo updates from field workers | belongs to one `renovation_cycle_id`; may reference a task/order/surplus item |
| `unit_readiness` projection | leasing-facing readiness bridge | belongs to one `unit_id`; derived from the active/most recent renovation cycle |

Design rule: Renovation Ops should keep the operational data model separate from Leasing, and expose only a thin readiness projection outward.

## Apartment / unit linkage

Renovation Ops should attach to `unit_id` first, not to lead, visit, or lease state.

Recommended linkage rules:

- one `unit` can have many `renovation_cycles` over time
- only one `renovation_cycle` for a given unit should be active at a time
- tasks, orders, receiving events, surplus items, and worker intake records all hang off the active renovation cycle
- a cycle may optionally retain references to the prior lease or vacancy source for traceability, but those references must stay optional and should not become workflow dependencies
- if a unit is re-renovated later, create a new cycle rather than reusing the old one

This keeps the Renovation Ops story centered on the apartment itself and prevents the module from drifting into lead/lease lifecycle logic.

## Readiness bridge back to Leasing

Leasing should not read Renovation Ops internals. It should consume a narrow readiness contract.

Recommended bridge shape:

- internal ops state: `planned`, `active`, `blocked`, `ready_for_leasing`, `handed_off`, `closed`
- leasing-facing state: `not_ready`, `ready`, `leased`

Suggested projection fields:

- `unit_id`
- `ops_status`
- `leasing_status`
- `current_renovation_cycle_id`
- `blocking_count`
- `blocking_summary`
- `ready_at`
- `handed_off_at`
- `leased_at`
- `updated_at`

Suggested transition rules:

- `active` becomes `blocked` when a task, material, access issue, or inspection issue prevents progress
- `blocked` becomes `ready_for_leasing` only when the unit has no open blockers and the final work checklist is complete
- `ready_for_leasing` is the only state Leasing needs before it can treat the unit as market-ready
- `leased` is a downstream leasing outcome, not a renovation outcome

Write authority:

- Renovation Ops writes the readiness projection
- Leasing reads the readiness projection
- Leasing does not mutate renovation tasks, orders, receipts, or worker intake records

## Boundaries that prevent workflow mixing

Hard boundaries:

- do not store renovation tasks inside lead, visit, renewal, or lease tables
- do not push worker photos/messages into generic communication logs if they are operational renovation records
- do not let Leasing screens expose renovation task lists or material history
- do not let Renovation Ops change lead stage, visit coordination state, payment state, or lease contract terms
- do not treat `units.status` as the renovation workflow model; keep the readiness bridge separate so the unit row stays simple
- do not mix generic CRM notes with actionable field work

Operational boundary: Renovation Ops is the physical readiness control plane. Leasing is the consumer of readiness, not the owner of the workflow.

## Recommended implementation sequence

### Backend first

1. Add the Renovation Ops data model:
   - renovation cycle
   - task
   - order
   - receiving event
   - surplus item
   - worker intake record
   - readiness projection
2. Add migrations and model validation for the new tables/entities.
3. Add service logic for state transitions and readiness projection updates.
4. Add API endpoints for Renovation Ops management and a read-only leasing-facing readiness endpoint.
5. Add activity logging for all mutating actions and readiness changes.

### Frontend second

6. Build the Renovation Ops dashboard and unit drill-down views.
7. Surface the readiness bridge in Leasing as a compact badge or summary only.
8. Keep Leasing UI read-only with respect to renovation details.

### Handoff checkpoint

Before any UI implementation expands beyond the readiness badge, verify that:

- the backend state machine is stable
- the unit-level linkage is correct
- the leasing-facing response contains no renovation internals
- the ops dashboard can explain why a unit is blocked or ready without involving Leasing screens

## Recommended owner split

- Product / boundary: CEO
- Data model / backend APIs: Backend Engineer
- Worker intake / SMS / MMS / integrations: Integrations Engineer
- Operations dashboard / UI: Frontend Engineer
- Readiness bridge and cross-module handoff: Backend Engineer + Frontend Engineer

## Downstream summary

Renovation Ops is a standalone module that owns apartment turnover work, field updates, materials, blockers, receiving, and surplus reuse. Leasing only consumes the unit readiness signal and must not absorb Renovation Ops workflow detail.
