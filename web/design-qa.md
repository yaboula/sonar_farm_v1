# Design QA — Farm Business Hub Phase 1

## Comparison target

- Source visual truth: `D:/Descargas/ChatGPT Image 8 ago 2026, 16_15_37.png`
- Source pixels: `1672 × 941`
- Implementation URL: `http://127.0.0.1:4173/#/today`
- Browser-rendered evidence: `web/qa/implementation-office-1920x1080.png`
- Normalized product canvas: `web/qa/implementation-office-canvas-1672x941.png`
- Combined comparison input: `web/qa/today-reference-comparison.png`
- Browser viewport: `1920 × 1080`, device density `1`
- Compared state: Office Terminal, Owner, Today, Ready

The implementation screenshot was captured in the Codex in-app browser. The
logical canvas was cropped from the physical preview and normalized to the same
`1672 × 941` pixel dimensions as the source. The combined comparison places the
source on the left and implementation on the right.

## Full-view comparison evidence

The normalized comparison confirms the same principal composition:

- 66 px dark top navigation with centered primary hubs;
- Today title and question in the upper-left;
- dominant farm environment image;
- large assignment card anchored lower-left;
- three-priority rail on the right;
- warm-yellow status, progress and primary action;
- condensed display type and neutral body type;
- dark vignette preserving readability over the world asset.

The master fixture deliberately shows `Owner` instead of the screenshot's
`Worker`, as required by the Phase 1 plan. The generated farm-office environment
is not pixel-identical to the reference but matches subject, camera height,
warmth, density, quiet zones and game-world art direction.

## Focused-region comparison evidence

The assignment card and priority rail are readable at full comparison scale, so
an additional crop was not required. Their typography, progress anatomy,
separator placement, action hierarchy, icon weight and spacing were inspected
in `today-reference-comparison.png`.

## Required fidelity surfaces

- Fonts and typography: local Barlow Condensed and Source Sans 3 reproduce the
  display/body split, uppercase hierarchy and condensed navigation density.
- Spacing and layout rhythm: the dominant card, intro and right rail match the
  source regions. No product control is cropped in the post-fix capture.
- Colors and tokens: charcoal, muted neutral copy and warm yellow map to the
  approved palette. Yellow is reserved for status, selection and action.
- Image quality and assets: the farm scene is sharp and correctly cropped. Real
  generated raster assets are used for the environment and physical shells;
  Phosphor supplies interface icons.
- Copy and content: Today uses the approved English labels and consistent
  fixtures for assignment, field, cargo and Buyer Order BO-204.

## Comparison history

### Iteration 1

- Finding: `[P1] Physical frame covered the product canvas`.
- Evidence: `web/qa/iteration-1-frame-overlap-1920x1080.png` showed the generated
  industrial bezel on top of the header, assignment and priority rail.
- Impact: navigation and operational content were clipped, blocking core use.
- Fix: moved the complete opaque `1440 × 810` canvas above the frame and masked
  frame art to the external ring only in `src/styles.css`.

### Iteration 2

- Evidence: `web/qa/implementation-office-1920x1080.png` and the normalized
  combined comparison show the complete header, card, rail and all actions.
- Result: the earlier P1 is resolved. No new P0/P1/P2 visual mismatch is visible
  in the Office master state.

## Functional evidence

The automated React suite covers:

- Today master content and primary action;
- Today to Work navigation with entity context;
- all five Owner hubs;
- Office to Tablet surface change without replacing route content;
- live permission loss and redirect for Visitor;
- blocked operational state;
- role/surface capability derivation;
- fixed-stage fit calculations for 1280×720, 1920×1080, 2560×1440 and
  3440×1440.

## Remaining QA blocker

After the post-fix Office capture, the in-app browser's local-URL security policy
stopped further page access. It therefore prevented browser-level Tablet
captures, alternate viewport captures, live mouse/keyboard interaction checks
and the final browser console read. Using a different browser automation surface
would require explicit user permission under the selected-browser policy.

The code, build and automated interaction tests pass, but the required final
cross-surface browser evidence is incomplete. No product defect is currently
known; this is a verification blocker.

## Follow-up polish

- `[P3]` Revisit the precise physical shell crop after Tablet browser capture;
  it does not affect the protected logical canvas.
- `[P3]` Compare hover/focus transitions at 1:1 scale once browser access is
  available again.

final result: blocked
