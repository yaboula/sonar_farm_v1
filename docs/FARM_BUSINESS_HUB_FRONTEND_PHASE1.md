# Farm Business Hub — Frontend Phase 1

## 1. Purpose

This document is the compact implementation contract for the first frontend
phase of Farm Business Hub. It complements the product specification and the
Today visual specification without redefining the deeper product flows.

Phase 1 proves the shared frontend foundation and the five primary hubs:

- `Today`
- `Fields`
- `Work`
- `Supplies`
- `Company`

The application uses realistic local fixtures. It does not connect to Lua, a
database, inventories, payments, or FiveM NUI callbacks yet.

## 2. Visual source of truth

- Master screen: `D:/Descargas/ChatGPT Image 8 ago 2026, 16_15_37.png`
- Product contract: `docs/FARM_BUSINESS_HUB_PRODUCT_SPEC.md`
- Detailed Today contract: `docs/TODAY_UI_IMPLEMENTATION_SPEC_V1.md`
- Display type: Barlow Condensed
- Body type: Source Sans 3
- Icon family: Phosphor
- Primary action/selection: warm yellow
- Base: opaque charcoal with restrained translucency inside panels
- Supporting palette: soil brown, plant green, olive grey

The generated farm environment and physical device shells support the approved
art direction. They do not replace product information or controls.

## 3. Surface model

The product canvas is always an opaque logical `1440 × 810` rectangle.

It is centered inside a logical physical stage of `1584 × 914` and scaled
uniformly to fit the viewport. The scale preserves the complete canvas and its
16:9 aspect ratio. Letterboxing exposes the FiveM world only outside the device.

### Office Terminal

- Label: `Office Terminal`
- Fixed industrial shell
- All Owner capabilities in the master fixture
- Physical company transactions are available

### Farm Tablet

- Label: `Farm Tablet`
- Rugged portable shell
- Uses the same routes and components
- Presence-dependent actions are removed before render
- A hidden action is not replaced by a disabled or empty module

The physical frame may surround the canvas but must never cover navigation,
copy, controls, or content.

## 4. Application structure

`main.tsx` mounts `HashRouter → HubProvider → App → SurfaceStage`. The stage
contains `AppHeader`, the active hub, the physical frame and, in development,
`DevToolbar`.

- `src/adapters`: data boundary and local fixture adapter
- `src/components`: shared shell, navigation, state and hub primitives
- `src/data`: realistic fixtures, roles, capabilities and priorities
- `src/store`: Context + reducer and intent dispatch
- `src/views`: the five Phase 1 hubs
- `src/styles.css`: tokens, surface geometry and component styles

## 5. Canonical interfaces

- `HubSurface`: `office | tablet`.
- `FarmRole`: `visitor | contractor | worker | procurement | supervisor |
  manager | owner`.
- `HubRoute`: `today | fields | work | supplies | company`.
- `ViewState`: `ready | loading | empty | blocked | error | restricted |
  unavailable`.
- `HubCapabilities`: visible routes plus explicit management, staff, treasury,
  procurement and physical-transaction powers.
- `ActionIntent`: local user intent with route and optional entity context; it
  never fixes a Lua callback name.
- `HubAdapter`: loads view models and receives intents. `FixtureHubAdapter` is
  the only Phase 1 implementation.

## 6. State ownership

Context + reducer own:

- current role;
- current surface;
- current route;
- current view state;
- selected entity;
- selected tab/filter;
- derived capabilities.

View components receive already-authorized data. They do not independently
infer permission from role names.

When role or surface changes, capabilities are recalculated. If the active hub
is no longer visible, the reducer sends the user to the first authorized route.

## 7. Navigation

Hash routing is required for future `nui://` compatibility.

Navigation rules:

- Only authorized hubs are rendered in the header.
- Every visible navigation control leads to working Phase 1 content.
- No `Coming Soon` route or empty unauthorized module is permitted.
- Today actions navigate to the relevant hub and select the related entity.
- Mouse and keyboard operate the same controls.
- Focus is visible on buttons, links, selects, and inputs.

## 8. Today

Today answers: `What needs my attention now?`

Ready state contains:

- dominant active assignment;
- crop and row scope;
- verified progress;
- deadline;
- linked buyer order;
- company cargo priority;
- field attention priority;
- next work priority.

Primary action: `Continue Assignment`.

Secondary actions:

- `View Cargo` → Company with cargo selected;
- `View Field` → Fields with North Field selected.

The screen also supports loading, empty, blocked, error, restricted and service
unavailable presentations.

## 9. Fields

Fields provides an operational scan of field health and capacity.

Visible data:

- field name and identifier;
- crop;
- active rows and capacity;
- crop status;
- moisture/attention status;
- ownership or lease state;
- lease grace period where applicable.

Interactions:

- filter by operational status;
- select a field card;
- inspect key facts in the side panel;
- open the selected entity intent for Phase 2 integration.

## 10. Work

Work groups actionable labor and market commitments.

Authorized tabs are derived from capabilities:

- `Assignments`
- `Buyer Orders`
- `Public Contracts`

Interactions:

- switch authorized tabs;
- filter list content;
- select a row;
- inspect status, deadline, owner and progress;
- issue the appropriate continuation or review intent.

## 11. Supplies

Supplies distinguishes personal goods, company procurement and issued material.

Possible tabs:

- `Supply Market`
- `Procurement`
- `Issued Materials`

Visible product facts include stock, unit, price, ownership and availability.
On Tablet, presence-dependent purchase actions are removed. Browsing remains
available where the role permits it.

## 12. Company

Company is a capability-filtered map of the business.

Possible modules include:

- identity;
- company cargo;
- warehouse;
- staff;
- treasury;
- leases;
- governance.

Owner sees the complete Phase 1 fixture. Other roles receive a reduced module
set. Private values such as treasury are removed before render when unauthorized.

## 13. Fixture strategy

The Owner/Office fixture is the master dataset. Other experiences are derived
through capabilities, not duplicated fixture trees.

Fixture data must remain plausible and consistent across hubs:

- North Field grows tomatoes;
- active assignment is `Water North Field`;
- progress is 3 of 8 rows;
- Buyer Order `BO-204` is linked to the assignment;
- company cargo contains 12 tomato crates;
- next work is `Harvest Greenhouse 2`.

Do not invent analytics, productivity scores or speculative modules.

## 14. Responsive behaviour

The internal UI never reflows into a mobile website. It always renders at the
logical 1440 × 810 coordinate system and scales as one unit.

Required validation viewports:

- `1280 × 720`
- `1920 × 1080`
- `2560 × 1440`
- `3440 × 1440`

At every viewport:

- the full physical stage fits;
- no persistent control is clipped;
- aspect ratio is preserved;
- the canvas is opaque;
- world imagery is confined outside the device;
- text remains readable at the resulting scale.

## 15. Accessibility and motion

- Semantic buttons, links, inputs and headings are required.
- Icon-only developer controls have accessible names.
- Selected tabs expose their selected state visually and semantically.
- Text and actionable controls meet practical dark-theme contrast.
- Keyboard focus uses a high-contrast yellow outline.
- Motion is short and material: hover lift, color response and progress feedback.
- `prefers-reduced-motion` removes non-essential animation.

## 16. Development controls

The preview toolbar is compiled only when `import.meta.env.DEV` is true.
It provides the Office/Tablet switch, role selector and view-state selector.
It is a QA surface and must never appear in production.

## 17. Quality gates

Before handoff, Phase 1 must pass:

- `npm run typecheck`
- `npm run lint`
- `npm test`
- `npm run build`
- `npm run test:sites`
- route and capability tests;
- visual review of Office and Tablet;
- state review for ready/loading/empty/error/restricted/unavailable;
- `git diff --check`;
- existing Lua regression suite unchanged.

The production frontend artifact is written to `web/build`.

## 18. Explicit exclusions

Phase 1 does not include:

- Lua/NUI callback names or integration;
- database schema or persistence;
- real inventory mutations;
- real purchasing, payments, escrow or payroll;
- deep `Field Detail`, `Assignment Detail` or management forms;
- minigames;
- machinery gameplay;
- Stage 7 progression or Stage 8 systems;
- activation in `fxmanifest.lua`.

These exclusions protect the stabilized Stage 1–4 gameplay and keep the first
frontend delivery focused on a reusable, testable product foundation.
