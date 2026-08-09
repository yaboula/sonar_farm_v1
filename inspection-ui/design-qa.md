# Crop Inspection Pulse Rail — Design QA V3

## Evidence

- Source visual truth: `C:/Users/aboul/AppData/Local/Temp/codex-clipboard-69f7ad19-dd61-4890-9106-50969996442f.png`
- Direct normalized comparison: `D:/sonar_farm/inspection-ui/qa-reference-comparison-v3.png`
- Browser-rendered implementation:
  - `D:/sonar_farm/inspection-ui/qa-1280x720-v3.png`
  - `D:/sonar_farm/inspection-ui/qa-1453x720-v3.png`
  - `D:/sonar_farm/inspection-ui/qa-1920x1080-v3.png`
  - `D:/sonar_farm/inspection-ui/qa-2560x1080-v3.png`
- Source pixels: 1104 × 123.
- Normalized implementation crop: 1100 × 127 from a 1567 × 181 rail at the
  1920 × 1080 CSS viewport. Device scale is 1.
- State: Tomato · Flowering, Growth 68%, Health 84%, Water 42% low,
  Nutrients 61% stable, Weeds 38% elevated and Pests 12% low.
- Browser: Codex in-app Chromium browser against the local Vite runtime.
- Console: no warnings or errors.

## Findings and fixes

- [P1 resolved] Recommended Action remained an implied gameplay instruction.
  - Fix: the entire region, its helper copy and its visual affordance were
    removed. The HUD contains no buttons and does not take focus.
- [P1 resolved] Dominant Diagnosis repeated a transient result instead of
  teaching the system.
  - Fix: a Field Guide now rotates six concise lessons about water, nutrients,
    weeds, pests, protection expiry and the no-care forecast every 6.5 seconds.
    The authoritative diagnosis only prioritizes the first lesson; later
    rotation is local and creates no network traffic.
- [P1 resolved] Curve hue represented metric category rather than agronomic
  meaning.
  - Fix: the authoritative metric status now maps to semantic tones: severe,
    critical and high are risk/orange-red; low and elevated are watch/amber;
    stable is good/green; unaffected is neutral gray. The visible legend makes
    this grammar explicit.
- [P2 resolved] Removing one region left the remaining content tracks
  underweighted.
  - Fix: the rail is now a deliberate three-part grid: crop identity, four
    conditions and Field Guide. The metric area received the released width,
    preserving chart legibility at every checked breakpoint.

## Full-view comparison

The source and final implementation were placed in one normalized comparison
image. The implementation retains the approved pulse-rail anatomy, transparent
charcoal surface, compact crop identity, four real trend plots and strong
operational numbers. The intentional product change replaces the two right-hand
diagnosis/action blocks with a single passive teaching block.

At 1280 × 720 the rail still begins after the configured 335 px minimap inset
and ends at the 18 px safe margin. The rail, Field Guide and footer all report
`scrollWidth == clientWidth`; no content overlaps or clips. The 1453 × 720,
1920 × 1080 and 2560 × 1080 captures also preserve the hierarchy.

## Focused-region comparison

The identity, condition plots, Field Guide and footer were inspected at full
resolution because those details are too small to judge reliably in a whole
screen capture.

- All four plots use solid history, a NOW marker and a dashed forecast.
- Current fixture state correctly renders three watch curves and one good curve.
- The Field Guide counter advances from one through six without interaction.
- There is no Recommended Action or Dominant Diagnosis copy in the DOM.
- The rail contains zero buttons and remains pointer-free.

## Runtime and content authority

- Production still starts empty and only `inspection:open` can provide the
  payload. The production build verifier passed and found no fixture markers.
- Crop identity, values, status, protection, timing, samples and diagnosis
  priority all come from `InspectionPayloadV1` produced by Lua.
- The six lessons and semantic labels are static interface education, not crop
  state or simulated measurements.
- Vitest verifies empty startup, authoritative open/update/close behavior,
  semantic curve tones and timed lesson rotation.

## Required fidelity surfaces

- Fonts and typography: Barlow Condensed preserves the reference's narrow,
  high-density hierarchy; condition percentages and footer times remain the
  heaviest information.
- Spacing and layout rhythm: the three-region grid is balanced after removing
  the action block, and all checked safe-zone widths remain free of overflow.
- Colors and tokens: amber, orange-red and green now have stable semantic
  meanings; neutral gray avoids falsely grading disabled conditions.
- Image quality and assets: canonical transparent crop artwork and Phosphor
  icons remain crisp; no placeholder, emoji, CSS-art or handcrafted icon was
  introduced.
- Copy and content: lessons are short, causal and system-specific; the HUD no
  longer suggests an unavailable direct action.
- Accessibility and motion: the guide uses `aria-live="polite"`, all trend
  charts retain accessible names, and reduced-motion still disables rail entry.

## Comparison history

- V2 established the numeric hierarchy, time readability, transparency,
  monotone trend treatment and production fixture gate.
- V3 pass 1 removed the action block, introduced the Field Guide and semantic
  curve tones. Responsive capture found no P0/P1/P2 overflow or hierarchy issue.
- V3 final direct comparison confirmed the intentional right-side replacement
  while preserving the selected visual language.

## Follow-up polish

- P3: confirm risk/orange-red over the server's real terrain grading by testing
  a severe or critical condition during the in-game E2E.

final result: passed
