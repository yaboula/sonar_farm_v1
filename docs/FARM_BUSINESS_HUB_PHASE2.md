# Farm Business Hub — Phase 2

Status: **complete**. Frontend V1 is frozen as version `1.0.0` in
`web/src/frontendV1Contract.ts`; the release gate and integration boundary are
recorded in `docs/FARM_BUSINESS_HUB_FRONTEND_V1_RELEASE.md`.

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

Product selection inside these dialogs uses the reusable `FarmSelect`
combobox/listbox. It owns the charcoal/yellow visual states, pointer and keyboard
behavior, focus management, disabled options and outside/Escape dismissal. Native
operating-system select popups are not used in the product UI.

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

## Increment 2.2 — Work and Supplies complete

### Work access model

- Visitor: published Public Contracts only.
- Contractor: their Active Contract, Progress and Completion.
- Worker and Procurement: their own Assignments only.
- Supervisor: team Assignments and Create Assignment.
- Manager and Owner: Assignments, Buyer Orders and Public Contract Management.
- Unauthorized tabs are removed before render. Deep links return Restricted.

### Work routes and behavior

- `/work/assignments/new` creates a funded internal Assignment.
- `/work/orders/:orderId` owns Buyer Order planning and fulfillment transitions.
- `/work/contracts/:contractId` serves public and management contract detail.
- `/work/contracts/new` creates a funded draft before publication.
- `/work/contracts/active/:contractId` is the contractor workspace.
- `/progress` verifies steps and `/completion` presents the final receipt.

Work list search, tab and selection live in the URL/context and survive deep-view
return. All economic and permission-sensitive actions are supplied by the
adapter. Confirmation is mandatory for accepting commitments, publication,
submission, completion, rejection, abandonment and cancellation.

Public Contract acceptance is atomic in the fixture repository. It reserves the
contract once and changes the preview context from Visitor to Contractor. The
contractor supplies personal materials. Reward escrow, cargo ownership, delivery
destination and failure consequences stay visible throughout the lifecycle.

Buyer Orders support accept, plan, reserve, prepare, complete and reject. Linked
Assignments are real routes. Warehouse and Company Cargo references remain
informational until their increments exist and never render false actions.

### Supplies access model

- Every role can make a personal Supply Market purchase.
- Procurement, Manager and Owner can select Company Funds and view Procurement.
- Manager and Owner can approve or reject requests.
- Procurement, Manager and Owner can resolve Issued Materials custody.
- Tablet supports catalog and review but never executes a physical transaction.

### Supply routes and behavior

Supply Market provides search, category filtering, supplier availability,
restock information, quantities, payer selection and a functional cart. Catalog
fixtures cover seedlings, seeds, hand tools, watering, fertilizer and pest
treatment. Essential planting stock is permanent; other inventory may sell out.

`/supplies/purchases/:purchaseId/review` shows line pricing, fees, payer,
ownership, balances, budget authority, capacity and fulfillment. Office
confirmation revalidates permission, funds, budget, transaction limit and stock,
then updates the in-memory repository and creates a receipt. Tablet produces an
Office handoff without mutating money or stock.

Company Procurement exposes budget, remaining authority, transaction limit,
allowed categories, requests, recent purchases and policy attention. Issued
Materials records employee, Assignment, issued/used/remaining quantities,
custody status and authorized return/discrepancy actions.

### Adapter contracts

`HubViewRequest` now includes Assignment creation, Buyer Order detail, Contract
detail/creation and Purchase Review. `ActionIntent` includes every Work and
Supplies mutation. `IntentResult` can return an entity id, context update,
receipt, handoff or invalidation signal.

The adapter owns mutable repositories for Assignments, Buyer Orders, Contracts,
supplier stock, purchases, balances, procurement requests and issued materials.
Reload resets all fixtures. UI components never invent an available action or
economic consequence.

### Completion gate

- Every Work/Supplies route has loading, empty, error, restricted and unavailable
  coverage through the shared state contract.
- Domain states cover draft, reserved, active, blocked, expired, completed,
  failed, cancelled, sold out and permission/funds/budget/stock failures.
- Office and Tablet share the opaque 1440 × 810 product canvas.
- Mouse, keyboard, focus, Escape dismissal and confirmation behavior are tested.
- Typecheck, lint, Vitest, production build, Sites packaging and Lua regression
  remain mandatory before commit.

## Increment 2.3 — Fields operating system

### Operating model

Fields uses a stable `Field → Row → Slot → Plant` hierarchy. A Field owns
territory, access and lease state. A Row is the minimum planning and Work scope.
A Slot is a persistent physical position. A Plant is temporary agronomic state
inside that Slot. Public contracts can grant temporary access, but every Field
remains company operated.

Business links use `fieldId`, `rowId` and `slotId`. Array position is never an
identity. `legacyIndex` is retained only as a future bridge aid.

### Routes and preserved context

- `/fields` is a role-adapted portfolio.
- `/fields/:fieldId` is the shared Field, Row and Slot operating map.
- `layer`, `row`, `slot` and `panel` live in the URL query.
- The map retains its own vertical Row scroll position when Work temporarily
  replaces the deep view.
- Return to Fields restores portfolio filter, search and selected Field.

### Access model

- Worker sees all Field summaries and full detail only for assigned Rows.
- Procurement adds Crop Plan and material-demand context.
- Supervisor sees agronomy, planning and team Work without company economics.
- Manager and Owner receive the full operational and business context.
- Contractor receives only the Active Contract Field and exact contracted Rows.
- Visitor has no Fields route. Abandoning a contract removes temporary access.

The adapter removes unauthorized plants, slots, events, yield and material data
before render. Components do not infer access from role labels.

### Spatial map and layers

The central visualization is SVG generated from authoritative normalized
topology. It supports 20 × 20 / 400 Slots through a fixed 0° grid with no zoom
or free pan. Its own vertical viewport presents 10 clear Rows at a time and
scrolls to Rows 11–20. Selecting a Row reveals up to 20 Slots across the same
rectangle. Keyboard focus roves across Rows and Slots with arrows; Enter
inspects and Escape returns to the parent scope.

Every Row owns an independent authoritative count of 2–20 Slots. Rendering,
capacity, planning and navigation use stable Slot IDs from that Row rather than
assuming a rectangular topology. Moving vertically between unequal Rows keeps
the nearest proportional Slot position.

Layers are `Overview`, `Water`, `Health`, `Growth`, `Readiness`, `Work` and
`Crop Plan`. Readiness includes spoilage. Critical Slot diagnostics remain
explicit even when the selected scope is a Row or Field.

Office keeps map, context and business inspector visible together. Tablet uses
the same routes and data with a narrower inspector. Neither surface renders live
player/team positions or remote farming controls.

### Diagnostics and event ledger

Diagnostics arrive fully resolved from the adapter: severity, scope, evidence,
cause, safe window, impact and authorized next action. V1 emits only water,
health, growth, readiness, spoilage, occupancy and timestamp-backed findings.
Pests, fertilizer, pruning and ties remain type-compatible but hidden.

The ledger stores operational events rather than continuous telemetry: planted,
watered, inspected, harvested, Crop Plan changed, Work linked, access changed
and restriction applied.

### Crop Plans and Work handoff

Crop Plans progress through `Draft → Reserved → In Execution → Completed` or
`Cancelled`. The UI currently creates reviewed Reserved plans. One Row accepts
one crop and one active reservation. Occupied, inaccessible or already-reserved
scope is excluded with a reason and the estimated material need is shown before
confirmation.

Reservation never plants. Management explicitly creates an Assignment or
Public Contract. The Work form receives stable scope and `sourcePlanId`; creation
moves the plan to In Execution and locks cancellation. Slot-level exceptions
remain Row attention and never become single-Slot Assignments.

### Synchronization contract

The fixture and future bridge share `FieldSubscription` and ordered
`FieldDelta` contracts:

1. Load topology with `topologyRevision`.
2. Load an authorized snapshot with `stateRevision`, `sequence` and `serverTime`.
3. Apply strictly sequential, idempotent Slot and Crop Plan deltas.
4. Ignore duplicate sequence values.
5. Reload on gaps, invalidation or topology mismatch.
6. Derive time-sensitive presentation from `serverTime`.

The Hub stream remains separate from proximity-based prop streaming. React owns
normalized positions only; future world-coordinate resolution stays outside UI.

### Master fixtures and completion gate

- North Field: 12 × 8, ASG-1048 and explicit Rows 4–8 water attention.
- Greenhouse 2: 6 × 8, mature tomatoes and a linked Buyer Order.
- East Field: homogeneous Rows plus the exact Contractor Row D scope.
- Orchard Annex: empty, Lease Grace Period and planting suspended.
- Scale Field: technical 20 × 20 fixture used only for topology/keyboard tests.
- Mixed Topology Field: deterministic 2–20 Slot-per-Row fixture used to verify
  variable capacity, stable identities and proportional keyboard navigation.

Completion requires role and surface redaction, deterministic aggregation,
exclusive Crop Plans, stable Work scope, ordered delta/resync tests, all shared
states, mouse/keyboard access, Office/Tablet visual QA, build/Sites/Lua regression
and no dead actions.

## Increment 2.4 — Company business center

### Authority model

Company is the source of truth for identity, people, assets, obligations,
Treasury and ownership. `Sonar Farm` is the immutable product brand;
`Grapeseed Farm Co.` is the initial player company and can be renamed.

The Company dashboard removes unauthorized areas before render and groups real
destinations under Operations, People, Finance and Ownership. Procurement stays
owned by Supplies. Company exposes only its budget summary and route.

`HubSurface` describes Office or Tablet. `HubPresence` independently describes
remote, office, warehouse or registry presence. Available actions require both
the relevant capability and, where applicable, the physical presence supplied
by the adapter.

### Public and operational routes

- `/company/profile` exposes public identity, opportunities and allowed paths.
- `/company/jobs/apply` owns one persistent application per character.
- `/company/business-for-sale` presents an immutable public listing.
- `/company/cargo` redacts custody to the actor unless team access is granted.
- `/company/warehouse` owns Stock, Reservations, Incoming and Discrepancies.
- `/company/warehouse/wholesale/:saleId/review` settles unreserved surplus.
- `/company/staff` and member/application routes own employment authority.
- `/company/treasury` separates cash, commitments, income and valuation.
- `/company/ledger` is immutable, filterable and actor-redacted.
- `/company/leases` and detail synchronize territorial access with Fields.
- `/company/roles` and `/company/identity` are Owner-only governance.
- `/company/sale`, review and transfer own the complete resale lifecycle.

Unknown identifiers render an explicit unavailable/not-found state. Permission
loss increments `capabilitiesRevision`; the open view reloads against the new
template and becomes Restricted without retaining private data or actions.

### Cargo, Warehouse and money

Company Cargo retains product, quality, origin, custodian, linked Work,
destination and restrictions. Warehouse stock separates total, available,
reserved and incoming quantities. Buyer Order reservations are never eligible
for wholesale sale.

Wholesale confirmation requires Warehouse presence and commits stock reduction,
Treasury credit and one idempotent Ledger settlement together. Work and Supplies
use the same `CompanyFixtureRepository`; final company purchases no longer own a
parallel balance.

Treasury separates available balance, Contract escrow, Assignment pay, Lease
obligations and pending Buyer income. Warehouse valuation is explicitly not
cash. There is no withdrawal action. An Owner contribution requires Office
surface and presence, debits personal funds, credits Treasury and writes Ledger.

All Company money uses deterministic English-US separators regardless of host
locale. Reloading the page resets the in-memory fixture state.

### People and land

Applications support draft, submit, withdraw, interview, accept and reject with
one active record per character. Invitations grant no access until the invited
character accepts. Normal onboarding is Worker; elevated initial roles are
provided by adapter authority. The Owner cannot be removed outside transfer,
and active Work, cargo or issued materials block Staff removal.

Leases distinguish permanent starter land, active recurring land, available
land and the 24-hour Grace Period. During grace, planting is suspended while
care and harvest remain valid. Paying Orchard Annex removes its Field
restriction; starting Riverside creates its stable topology; ending a Lease
makes the Field inaccessible. Treasury, Ledger, Company and Fields update from
one adapter mutation.

### Governance, identity and ownership

Role policies contain editable capability templates, financial limits and
locked protections. Manager never inherits Owner controls. Gameplay role
transitions preserve the stable actor identity; the development role selector
alone changes to another fixture actor.

Rename changes only the player company name. It requires Owner, Office, a valid
name, Treasury fee and inactive cooldown. The Registry fee, new name, Ledger
entry and listing invalidation commit together.

A Business Sale listing captures a versioned snapshot of asking price,
Treasury, Warehouse valuation, Staff, Leases, obligations, fee and proceeds.
Reservation moves buyer personal funds into escrow once. Material changes refund
escrow and invalidate the public version. Buyer and seller confirmations occur
at the Registry. Final settlement atomically releases escrow, changes Owner,
keeps Staff/Warehouse/Treasury, removes the former Owner and writes one released
sale entry. A second buyer or stale confirmation changes no state.

### Completion gate

- Visitor, Contractor, every Staff role, Manager and Owner receive only their
  authorized data and routes.
- Office and Tablet share the opaque 1440 × 810 canvas; internal scrolling keeps
  persistent actions visible.
- Every mutation has adapter-provided confirmation copy and stale-action
  revalidation; no `Coming Soon`, decorative buttons or empty modules exist.
- Shared loading, empty, error, restricted and unavailable states cover every
  Company family.
- Adapter tests prove custody redaction, atomic wholesale, employment uniqueness,
  Treasury authority, Ledger filtering, Lease/Field synchronization, live
  permission loss, rename cooldown, escrow refund and atomic ownership transfer.
