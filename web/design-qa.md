# Design QA — Farm Business Hub Phase 2 / Assignment Detail

## Comparison target

- Original art-direction source: `D:/Descargas/ChatGPT Image 8 ago 2026, 16_15_37.png`
- Accepted V1 product source: `web/qa/phase2/v1-today-office-worker-1920x1080.png`
- Primary implementation evidence: `web/qa/phase2/assignment-detail-office-worker-1920x1080.png`
- Tablet evidence: `web/qa/phase2/assignment-detail-tablet-worker-1920x1080.png`
- Supervisor dialog evidence: `web/qa/phase2/assignment-review-supervisor-1920x1080.png`
- Select source: `C:/Users/aboul/AppData/Local/Temp/codex-clipboard-98d89fc2-9d0d-4c9a-9bfe-493dfdbca7e7.png`
- Reusable select evidence: `web/qa/phase2/farm-select-reassignment-open-1920x1080.png`
- Responsive evidence: `web/qa/phase2/assignment-detail-office-worker-1280x720.png` and `web/qa/phase2/assignment-detail-office-worker-3440x1440.png`
- Browser viewport and density: `1920 × 1080` at density `1` for the primary comparison; additional viewports `1280 × 720` and `3440 × 1440` at density `1`
- Logical product canvas: opaque `1440 × 810`, uniformly scaled inside each physical surface
- State: Office Terminal, Worker, Ready, Assignment `ASG-1048`, `In Progress`

The implementation was rendered and exercised in the Codex in-app browser. The
V1 source and Assignment Detail capture were opened together in one comparison
input at equal pixel size. The original art-direction image was also compared in
the same input with the primary implementation to verify the visual lineage.

## Full-view comparison evidence

Assignment Detail preserves the accepted V1 system instead of introducing a
second dashboard language:

- identical physical Office/Tablet framing and opaque 16:9 product canvas;
- the existing condensed display/body typography split;
- the same charcoal hierarchy, warm-yellow selection and muted olive success;
- the approved header proportions, navigation rhythm and world vignette;
- one dominant operational objective, one evidence rail and one persistent
  contextual action rather than a generic grid of independent dashboard cards;
- real Phosphor icons with the same weight and alignment as V1.

The deep view is intentionally denser than Today because it is an auditable work
record. Its title, requirements and action remain above the fold while history,
terms and materials use one explicit internal scroll region. No page-level
overflow or hidden persistent control was detected.

## Focused-region comparison evidence

Focused inspection covered the title/deadline band, verified-requirement rows,
reserved-pay panel, issued-material row, action bar and Supervisor review dialog.
At `1920 × 1080` the small copy remains readable, the `3 / 8` measure aligns with
the progress rail, status colors retain their semantic role, and the dialog
keeps a clear primary/secondary decision hierarchy over a subdued product view.

## Required fidelity surfaces

- Fonts and typography: local Barlow Condensed remains exclusive to display,
  status and action text; Source Sans 3 handles instructions and operational
  data. Weight, line height, tracking, wrapping and optical hierarchy match V1.
- Spacing and layout rhythm: header, breadcrumb, title band, two-column record
  and persistent action bar form a stable vertical sequence. Borders stay
  discreet and square-edged rather than becoming generic rounded cards.
- Colors and tokens: approved charcoal, warm yellow, earth brown and olive are
  reused from V1. Yellow remains reserved for selection, verified progress and
  primary action; contrast is sufficient in all inspected states.
- Image quality and assets: the existing raster farm-world and physical surface
  assets remain sharp and correctly masked. No placeholder imagery, CSS art,
  emoji, handcrafted SVG or synthetic icon substitute was introduced.
- Copy and content: all visible copy is specific to the farming operation and
  uses canonical identifiers, rows, tools, supervisors, payout rules and audit
  events. No invented analytics or future module appears.
- Icons: all operational icons come from Phosphor and share size, stroke/fill
  behavior and baseline alignment with the V1 header and Today controls.

## Responsive and surface evidence

- `1280 × 720`: Office frame fits without clipping; logical hierarchy and CTA
  remain visible.
- `1920 × 1080`: Office and Tablet render complete physical shells with opaque
  product backgrounds and the world visible only around the device.
- `3440 × 1440`: the canvas scales uniformly and remains centered; ultrawide
  space stays outside the product instead of stretching its internal layout.
- Tablet reuses the same deep-view route and components while changing only the
  physical shell, surface label and capability context.

## Interaction and accessibility evidence

Browser-validated:

- Work search and tab query survive deep-link entry and `Back to Assignments`;
- `Resume Field Work` enters the simulated world handoff and returns with `3 / 8`
  verified progress unchanged;
- Worker and Supervisor receive different action bars from adapter-provided
  capabilities;
- Supervisor review opens an accessible labelled dialog with explicit Approve
  and Request Correction decisions;
- live role change to an unauthorized role produces Restricted;
- Office/Tablet switching keeps the current deep route;
- browser console contains no warnings or errors.
- the reusable Worker selector supports pointer selection, Arrow keys, Enter,
  Escape-without-closing-the-dialog, selected state and disabled confirmation.

Automated coverage additionally verifies Escape dialog dismissal, incomplete
submission rejection, state mutations, Manager/Owner Supervisor inheritance and
permission loss while the view is open.

## Comparison history

### Iteration 1

- Evidence: primary Office, Tablet, Supervisor-dialog and responsive captures.
- Findings: no actionable P0, P1 or P2 mismatch was found against the accepted
  V1 product source or original art direction.
- Result: no visual fix iteration was required. The first comparison passes.

### Iteration 2 — reusable product select

- Earlier finding: `[P2]` the operating-system option popup introduced a bright
  blue selection surface, platform typography and spacing that did not belong
  to the Sonar Farm design system.
- Fix: replaced the native product `<select>` with the reusable `FarmSelect`
  listbox/combobox component using the approved charcoal, warm yellow, local
  typefaces, Phosphor icons, focus states and short material motion.
- Post-fix evidence: the supplied source screenshot and
  `web/qa/phase2/farm-select-reassignment-open-1920x1080.png` were opened in one
  comparison input. The blue OS chrome is gone, selected/active states remain
  distinct, the menu aligns to the field and no nearby layout changed.
- Result: the P2 is resolved. No actionable P0/P1/P2 issue remains.

## Follow-up polish

- `[P3]` Revisit microcopy density when real backend error payloads replace the
  fixtures; this does not block the current product contract.

final result: passed
