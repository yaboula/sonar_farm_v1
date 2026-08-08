# Farm Business Hub — Phase 2

## Purpose

Phase 2 completes the deep frontend experiences defined by the product contract.
Views are delivered one at a time with local fixtures, interaction states, visual
QA and a small commit before the next view begins.

This phase does not implement Lua, NUI callbacks, persistence, real inventory,
payments, farming minigames or backend business rules.

## Delivery order

1. Daily operation: Assignment Detail, Field Detail, Company Cargo, Warehouse,
   Buyer Order Detail and Purchase Review.
2. Visitors and Contractors: Public Contract Detail, Active Contract, Contract
   Progress, Contract Completion, Company Profile, Business for Sale and Job
   Application.
3. Management: Buyer Orders, Public Contract Management, Create Contract, Staff,
   Applications, Application Review, Procurement, Treasury, Transaction Ledger,
   Leases and Lease Detail.
4. Ownership: Roles & Permissions, Company Identity, Business Sale, Sale Listing
   Review and Ownership Transfer Confirmation.

Existing hub lists are expanded only when their related deep view is delivered.

## Shared rules

- The product canvas remains opaque at a logical 1440 × 810.
- Office Terminal and Farm Tablet share routes and view components.
- FiveM world imagery is visible only outside the physical device.
- Barlow Condensed, Source Sans 3, Phosphor and the V1 color tokens remain the
  official design system.
- English remains the canonical UI language.
- Visible actions come from adapter data; components never infer permission or
  business validity from labels.
- Fixture mutations last for the browser session and reset on reload.
- No deep view may expose a dead button or an empty unauthorized module.

## Increment 2.1 — Assignment Detail

### User outcome

A Worker understands the exact objective, verified progress, location, issued
materials, deadline, reserved pay and payout conditions before returning to the
world. A Supervisor can review results and resolve exceptions without confusing
administrative actions with physical farming.

### Route and return

- Route: `/work/assignments/:assignmentId`.
- Breadcrumb: `Work / Assignments / {reference}`.
- Back destination restores Work tab, query and selected Assignment.
- Today links directly to `asg-1048`.
- Invalid identifiers show a recoverable not-found state.

### Master scenario

- Role: Worker.
- Assignment: `ASG-1048 · Water North Field`.
- Status: `In Progress`.
- Field: North Field, rows 4–8.
- Verified progress: 3 of 8 checks.
- Deadline: Today, 18:30.
- Reserved pay: $180.
- Primary action: `Resume Field Work`.

### Information hierarchy

1. Status, reference, title and objective.
2. Deadline, work area and assignee.
3. Verified requirements and total progress.
4. Blocker or Supervisor correction when present.
5. Audit history.
6. Assignment terms, materials, payout and cancellation copy.
7. Contextual action bar.

### Worker actions

- Assigned: `Accept Assignment`.
- In progress: `Resume Field Work`.
- Fully verified: `Submit for Review` with confirmation.
- Awaiting review: read-only waiting state.
- Completed, failed, expired or cancelled: read-only receipt.

`Resume Field Work` emits `assignment.resume`, produces a short world-handoff
state and does not mutate verified progress. Development mode provides a return
control. A future NUI bridge will close the Hub when `closeSurface` is true.

### Supervisor actions

- Awaiting review: `Review Result`.
- Approval releases the fixture's reserved pay and completes the Assignment.
- Correction requires a note and returns the Assignment to work without losing
  verified progress.
- Blocked: `Resolve Blocker` with a resolution note.
- Reassign and Cancel live under `Assignment Controls` and appear only when the
  fixture exposes those actions.
- Manager and Owner inherit the Supervisor experience in this increment.

### Confirmation policy

Submit, approve, correction, reassignment, cancellation and blocker resolution
use accessible modal dialogs. Cancellation and correction require notes. Resume
is not destructive and does not require confirmation.

### Fixture scenarios

- `asg-1048`: Worker in progress, partial verification.
- `asg-1052`: Worker assigned, ready to accept.
- `asg-1061`: Worker fully verified, ready to submit.
- `asg-1059`: Supervisor review, ready to approve or return.
- `asg-1060`: blocked by missing company material.

### Contracts

`HubViewRequest` is a discriminated union for hub and Assignment Detail loads.
`ActionIntent` is a discriminated union for accept, resume, submit, approve,
request correction, reassign, cancel and resolve blocker.

Assignment Detail data contains:

- identity, status, work type and objective;
- field, crop, scope, assignee and Supervisor;
- requirements and issued materials;
- payout terms and status;
- progress events, blocker and reviewer note;
- server-like `availableActions`.

`FixtureHubAdapter` owns the mutable fixture repository. Components load a view
model, dispatch an intent and reload only when the result reports a change.

### States

The view supports loading, error, unavailable, restricted, not found, assigned,
in progress, blocked, awaiting review, completed, failed, expired and cancelled.
Live permission loss replaces private content with Restricted.

### Acceptance

- Today opens the correct Assignment Detail.
- Work preserves its tab and query after return.
- Worker sees only personal Assignments and Worker actions.
- Supervisor, Manager and Owner receive Supervisor actions.
- Resume requests world handoff without progress mutation.
- Incomplete work cannot be submitted.
- Approval, correction, reassignment, cancellation and blocker resolution update
  only the in-memory fixture.
- All dialogs close with Escape and remain keyboard operable.
- Office and Tablet render the same complete canvas without clipping.
- V1 hubs and Lua regression tests remain unchanged.

## Per-view completion gate

Each following view must add its contract to this document, pass typecheck,
lint, frontend tests, build, Sites packaging and Lua regression tests, then pass
visual QA on Office and Tablet before receiving its own commit.

The in-app browser is the primary QA surface. If it blocks local access again,
QA stops and the blocker is reported before selecting a definitive solution.
