# Farm Business Hub — Frontend V1 Release Contract

Status: **closed for frontend integration**
Version: **1.0.0**
Closure date: **2026-08-09**

## Release outcome

Frontend V1 is the complete fixture-backed product contract for the Farm
Business Hub. It includes the approved visual system, the five adaptive hubs,
all deep views in the Product Owner specification, role and presence filtering,
local transitions, confirmations, receipts and shared failure states.

This release is ready to receive a FiveM adapter. It does not claim that the
fixture mutations are authoritative gameplay, persistent economy or server
validation.

## Stable product frame

- Logical product canvas: `1440 × 810`, always opaque.
- Surfaces: `Office Terminal` and `Farm Tablet`.
- Presence: `remote`, `office`, `warehouse`, `registry`.
- Roles: `Visitor`, `Contractor`, `Worker`, `Procurement`, `Supervisor`,
  `Manager`, `Owner`.
- Primary areas: `Today`, `Fields`, `Work`, `Supplies`, `Company`.
- Development preview controls never ship in the production build.
- Surface and presence remain independent dimensions.

The runtime manifest is `web/src/frontendV1Contract.ts`. Any breaking change to
its paths, context axes or adapter boundary requires a contract version change.

## Route inventory

### Main areas

- `/today`
- `/fields`
- `/work`
- `/supplies`
- `/company`

### Fields

- `/fields/:fieldId`

Row, Slot, layer and panel context stay inside Field Detail query state. Rows
and Slots use stable identifiers; array position is never business identity.

### Work

- `/work/assignments/new`
- `/work/assignments/:assignmentId`
- `/work/orders/:orderId`
- `/work/contracts/new`
- `/work/contracts/:contractId`
- `/work/contracts/active/:contractId`
- `/work/contracts/active/:contractId/progress`
- `/work/contracts/active/:contractId/completion`

### Supplies

- `/supplies/purchases/:purchaseId/review`

Supply Market, Procurement and Issued Materials remain authorized areas inside
the Supplies hub rather than artificial empty routes.

### Company

- `/company/profile`
- `/company/cargo`
- `/company/warehouse`
- `/company/warehouse/wholesale/:saleId/review`
- `/company/staff`
- `/company/staff/:memberId`
- `/company/applications`
- `/company/applications/:applicationId`
- `/company/jobs/apply`
- `/company/treasury`
- `/company/ledger`
- `/company/leases`
- `/company/leases/:leaseId`
- `/company/roles`
- `/company/identity`
- `/company/sale`
- `/company/sale/review`
- `/company/sale/transfer/:listingId`
- `/company/business-for-sale`
- `/company/business-for-sale/transfer/:listingId`

## Essential journey gate

The following journeys are complete with mutable in-memory fixtures:

1. Initial purchase of the unowned company.
2. Job Application through review and hiring.
3. Public Contract publication, reservation, execution and completion.
4. Internal Assignment creation, execution, review and payout result.
5. Personal Supply purchase.
6. Company Procurement purchase and approval.
7. Company Cargo routing and Warehouse custody.
8. Buyer Order planning, reservation and delivery.
9. Wholesale surplus review and atomic settlement.
10. Lease payment, Grace Period and Field restriction.
11. Business listing, escrow and atomic ownership transfer.

Fixture reload resets the journeys. This is deliberate and remains visible in
development only.

## Frozen adapter boundary

The UI depends on four public contracts:

- `HubAdapter`
- `HubViewRequest`
- `ActionIntent`
- `IntentResult`

The flow is:

`Route → access guard → adapter load → filtered ViewModel → intent → adapter
result → invalidation, context update or world handoff`

React must not infer permissions, economic consequences, available actions or
authoritative diagnostics from labels. The adapter filters private data before
render and supplies every valid action.

Frontend V1 intentionally does not define callback names, event names, payload
serialization, database tables or network transport. Those belong to the
versioned FiveM integration contract.

## State contract

Every family supports the shared states:

- `loading`
- `empty`
- `blocked`
- `error`
- `restricted`
- `unavailable`

Domain records additionally expose their explicit lifecycle states. A stale
action must fail closed, dismiss obsolete confirmation UI and reload the
authorized entity.

## Authority boundaries

- Fields owns topology, authorized snapshots, diagnostics and Crop Plans.
- Work owns Assignments, Buyer Orders and Contracts.
- Supplies owns catalog, purchase drafts, Procurement and Issued Materials.
- Company owns identity, Staff, Warehouse, Treasury, Ledger, Leases and
  ownership.
- Work and Supplies publish final monetary movements into Company; they do not
  maintain independent authoritative balances.
- Physical mutations require both an authorized capability and valid presence.

## Quality gate

Closure requires all of the following to pass from a clean dependency install:

- TypeScript typecheck.
- ESLint.
- Vitest frontend suite.
- Production build to `web/build`.
- Sites artifact tests.
- Lua syntax parse.
- Lua regression suite.
- `git diff --check`.
- tracked-file secret scan.

Browser evidence covers Today, Work, Assignment Detail, Field Detail, Purchase
Review, Warehouse and Company Profile. It includes Office, Tablet, Worker,
Owner and Visitor perspectives, physical-presence restrictions, 1280×720,
1920×1080, 2560×1440 and 3440×1440 geometry, and current console output.

The closure accepts no P0, P1 or P2 UX, visual, interaction or authorization
finding. Screenshot-only inspection is not a claim of complete WCAG compliance;
keyboard behavior, focus and semantics remain enforced by automated tests and
must be revalidated against the real NUI runtime.

## Accepted debt

- Backend error payloads may require a later P3 microcopy density pass.
- The future bridge must prove focus restoration and input capture inside CEF.
- Fixture time is deterministic; authoritative server time remains an
  integration responsibility.
- Current Field telemetry is limited to values the stabilized farming engine
  can justify.

## Explicitly outside Frontend V1

- Lua/NUI bridge and callbacks.
- Persistent database repositories.
- Real framework identity, balances, inventory and payments.
- Server-authoritative Company, Work and Supplies mutations.
- Farming minigames and machinery gameplay.
- Future analytics or modules hidden by the Product Owner specification.

## Entry condition for integration

Phase 3 may replace `FixtureHubAdapter` incrementally behind the frozen
interface. The first vertical should load real actor context and authorized
Today, Fields and Assignment data without changing the approved routes or view
components.

Frontend V1 is reopened only for a confirmed product defect or a versioned
contract change. New backend work must not quietly redesign the product.
