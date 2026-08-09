# Crop Inspection Pulse Rail — Design QA

## Evidence

- Source visual truth: `C:/Users/aboul/AppData/Local/Temp/codex-clipboard-908dece2-35e5-4ef0-89eb-28b30b95c287.png`
- Implementation screenshots:
  - `D:/sonar_farm/inspection-ui/qa-1453x720.png`
  - `D:/sonar_farm/inspection-ui/qa-1280x720.png`
  - `D:/sonar_farm/inspection-ui/qa-1920x1080.png`
  - `D:/sonar_farm/inspection-ui/qa-2560x1080.png`
- Source pixels: 1100 × 129.
- Reference-width implementation: 1453 × 720 CSS viewport at device scale 1;
  rail bounds 1100.6 × 132 CSS pixels at x=335, with the 27 px time rail below.
- Responsive implementation viewports: 1280 × 720, 1920 × 1080 and
  2560 × 1080 at device scale 1.
- State: Tomato · Flowering, Growth 68%, Health 84%, Water 42%, Nutrients
  61%, Weeds 38%, Pests 12%, weed diagnosis and Remove Weeds recommendation.
- Browser: Codex in-app Chromium browser, local Vite runtime.
- Console: no warnings or errors in the checked states.

## Full-view comparison

The source and the 1453 × 720 implementation were opened together for the
blocking comparison. The implementation preserves the source composition: crop
identity and dual progress at the left, four agronomic metric columns, diagnosis,
recommended action, matte charcoal surface, fine separators, warm-yellow
priority color and a slim horizontal footprint. The implementation intentionally
anchors the rail at the bottom of the gameplay viewport and starts at x=335,
after the standard minimap allocation.

At 1280 × 720 the rail remains entirely visible from x=335 to an 18 px right
inset. At 1920 × 1080 and 2560 × 1080 it expands the metric and diagnosis tracks
without stretching icons, crop art or typography. No persistent content crosses
the viewport or minimap boundaries.

## Focused-region comparison

The rail itself was inspected at approximately the source width. Typography,
metric readings, status color, crop asset, real curve markers, dashed forecast,
progress bars and the non-interactive recommendation are readable. A separate
crop was unnecessary because the source is already a single focused component
and the implementation rail occupies the same 1100 px comparison width.

## Required fidelity surfaces

- Fonts and typography: Barlow Condensed matches the narrow industrial display
  voice; Source Sans 3 preserves legibility for supporting copy. Hierarchy,
  uppercase labels, weights and wrapping match the compact reference.
- Spacing and layout rhythm: column separators, left identity block, metric
  cadence, diagnosis/action hierarchy and corner radii match. The narrow time
  rail is an intentional extension required by the approved real-time scope.
- Colors and visual tokens: near-black matte surface, muted warm foreground,
  yellow priority, blue water and green health/nutrient tokens match the source.
- Image quality and asset fidelity: the canonical transparent tomato crop asset
  is crisp and correctly scaled. Phosphor supplies all condition icons; no emoji,
  CSS-art icon or placeholder is visible.
- Copy and content: all visible values are the approved realistic fixture state.
  `NOW`, last care, ready time and `NO CARE FORECAST` add the requested temporal
  references. The recommendation has no chevron or interactive affordance.

## Findings

No actionable P0, P1 or P2 mismatch remains.

## Comparison history

- Pass 1: no P0/P1/P2 finding. The real-data curves are deliberately calmer than
  the illustrative source curves; their amplitude is governed by shared farming
  evaluation and must not be exaggerated for decoration. No visual fix was made
  after this comparison.

## Follow-up polish

- P3: evaluate the rail against the final production world/HUD palette during
  in-game E2E; the standalone preview uses a neutral solid field background.

## Implementation checklist

- [x] Source and implementation opened in the same comparison input.
- [x] Reference-width state checked.
- [x] 1280 × 720 checked.
- [x] 1920 × 1080 checked.
- [x] 2560 × 1080 checked.
- [x] Console checked with no errors or warnings.
- [x] Fonts, spacing, colors, image quality and copy reviewed.

final result: passed
