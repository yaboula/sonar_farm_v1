# Crop Inspection Pulse Rail — Design QA V2

## Evidence

- Selected visual truth: `C:/Users/aboul/AppData/Local/Temp/codex-clipboard-69f7ad19-dd61-4890-9106-50969996442f.png`
- Reported implementation before correction: `C:/Users/aboul/AppData/Local/Temp/codex-clipboard-fb0b83d4-3f2a-49f9-a7e0-96703fc9e41a.png`
- Corrected implementation:
  - `D:/sonar_farm/inspection-ui/qa-1453x720-v2.png`
  - `D:/sonar_farm/inspection-ui/qa-1280x720-v2.png`
  - `D:/sonar_farm/inspection-ui/qa-1920x1080-v2.png`
  - `D:/sonar_farm/inspection-ui/qa-2560x1080-v2.png`
- Source pixels: 1100 × 129.
- Reference-width implementation: 1453 × 720 CSS viewport, device scale 1;
  rail bounds 1100.6 × 132 CSS pixels at x=335 plus a 34 px time rail.
- State: Tomato · Flowering, Growth 68%, Health 84%, Water 42%, Nutrients
  61%, Weeds 38%, Pests 12%, weed diagnosis and Remove Weeds recommendation.
- Browser: Codex in-app Chromium browser, local Vite runtime.
- Console: no warnings or errors at any checked breakpoint.

## Findings and fixes

- [P1 resolved] Operational numbers lacked hierarchy.
  - Before: the ≤1500 px breakpoint reduced condition values to 19 px and
    Growth/Health to 22 px/weight 600.
  - Fix: Growth/Health are 27 px/700, condition values 29 px/700, and the
    desktop scale reaches 32–34 px. Growth and Health now place labels above
    values, matching the reference hierarchy.
- [P1 resolved] Time references were too small to scan in gameplay.
  - Before: the footer used a uniform 9 px/500 line.
  - Fix: semantic label/value pairs use 10 px labels and 13 px/700 values in a
    34 px rail. Last care, NOW, maturity and no-care window remain visible with
    no overflow at 1280 × 720.
- [P2 resolved] Surface was more opaque than the selected capture.
  - Before: main surface alpha 0.94 and footer alpha 0.91.
  - Fix: main surface alpha 0.88 and footer alpha 0.85, preserving world context
    without sacrificing contrast.
- [P1 resolved] Curves looked like thin, low-information lines.
  - Fix: curves now use adaptive real-value domains, monotone cubic smoothing,
    rounded 3 px history strokes, soft glow/area, a clear NOW marker and a
    dashed no-care forecast. Scaling amplifies real variation but never inserts
    decorative oscillation not present in the agronomic samples.
- [P0 resolved] Production fixture concern.
  - Fix: `App` starts with `null` and renders only after an inspection runtime
    message. The fixture is dynamically imported only under `import.meta.env.DEV`.
    The production verifier rejects known fixture markers in `dist`.

## Full-view comparison

The selected reference and corrected reference-width capture were opened in the
same comparison input. The corrected rail preserves the source anatomy, narrow
industrial typography, warm-yellow priority, transparent charcoal surface,
four agronomic plots and causal diagnosis. Numeric hierarchy is now stronger
than supporting copy, as required for an in-game instrument.

At 1280 × 720 the rail remains x=335 to an 18 px safe inset. All time values fit
inside a 924 px footer with `scrollWidth == clientWidth`; stage, diagnosis and
recommendation remain visible. 1920 × 1080 and 2560 × 1080 also pass without
overflow.

## Focused-region comparison

The identity metrics, four charts and footer were inspected separately through
computed browser styles. Final measured values:

- Growth/Health: 27 px, weight 700 at reference width.
- Water/Nutrients/Weeds/Pests: 29 px, weight 700.
- Time values: 13 px, weight 700.
- Surface: `rgba(8, 11, 8, 0.88)`.
- Four solid history paths, four dashed forecasts and four NOW markers.

## Backend/runtime verification

- Production build at `http://127.0.0.1:4174/` rendered an empty transparent
  root before any runtime message: zero rail elements, zero text, zero console
  warnings/errors.
- `npm run verify:production` confirmed runtime message handling is present and
  fixture identifiers are absent from compiled JavaScript.
- Vitest confirms `inspection:open` populates the rail, lightweight
  `inspection:update` preserves authoritative series, and `inspection:close`
  removes it.
- Visible crop values, timing, metrics, curves and diagnosis all originate in
  the Lua-produced `InspectionPayloadV1`; only UI labels, keyboard help and
  canonical crop artwork are static.

## Required fidelity surfaces

- Fonts and typography: Barlow Condensed 700 establishes the numeric hierarchy;
  Source Sans 3 remains limited to secondary prose.
- Spacing and layout: compact columns and separators match the source; the extra
  time rail is the approved functional extension and does not overflow.
- Colors and tokens: warm yellow, blue water, green health/conditions and a
  lightly transparent charcoal surface match the selected direction.
- Image quality: canonical transparent crop artwork and Phosphor icons remain
  crisp; no emoji, placeholder or fabricated icon is used.
- Copy/content: all agronomic values and diagnosis are runtime payload data; the
  recommendation remains informational and has no chevron/button affordance.

## Comparison history

- Pass 1 (`e1e677c`): user identified weak numbers, unreadable time rail, excess
  opacity, insufficient curve treatment and uncertainty about fixtures.
- Pass 2: hierarchy, transparency, chart rendering and production data gate were
  corrected. A 1280 px check exposed the crop stage truncating.
- Pass 3: stage moved below the crop title at ≤1500 px. Reference width, 720p,
  1080p and ultrawide all passed with no P0/P1/P2 findings.

## Follow-up polish

- P3: final alpha perception should be confirmed over the server's real terrain
  and custom HUD color grading during the in-game E2E.

final result: passed
