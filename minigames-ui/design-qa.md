# Tomato Initial Planting — Design QA

## Reference

- Gameplay composition and tone: the five approved `temp/general_reference_*.png` Tomato Initial Planting screens.
- Runtime asset source: the 24 approved PNGs from `temp/assets/`, copied without altering the source package.
- UI system: Barlow Condensed headings, Source Sans 3 body copy, Phosphor interface icons, warm-yellow action/selection, opaque charcoal surfaces.
- The provisional seedling logo is present in the runtime asset package for completeness but is not used as final branding.

## Responsive states to validate

- [x] 1920 × 1080: full-screen field HUD matches the reference hierarchy without a dashboard shell.
- [x] 1280 × 720: no document overflow; HUD, palettes, scene and result rails remain contained.
- [x] 1680 × 1050 (16:10): transparent internal scene remains letterboxed without stretching.
- [x] 2560 × 1080 (ultrawide): central diorama remains bounded while HUD rails stay anchored.
- [x] Device pixel ratios 1 and 2: measured Canvas backing-store ratio stays at 2 or lower.

## Interaction states

- PREPARE: dry-to-dug soil crossfade, radial coverage guide, shovel and soil particles.
- PLACE: seedling pickup/drag, tilt correction, drop feedback, root-relax confirmation.
- COVER: independent left/right soil contribution, light compaction, missed-drop feedback.
- WATER: movable/tiltable can, held pour, moisture grid absorption, droplets, ripple and puddle risk.
- RESULT: qualitative depth, alignment, aeration and hydration labels only.
- Shared composition: top-left crop identity, centered four-step rail and objective strip, left Tools, right Materials, central soil diorama, bottom gesture instruction.
- Full and Minimal help modes persist locally.
- Pointer, basic keyboard controls, visible focus, ESC cancel, `aria-live` status updates.
- Reduced-motion mode keeps feedback while reducing particle and mote counts.

## Browser validation — 2026-08-09

- Completed the full PREPARE → PLACE → COVER → WATER flow in the real browser preview.
- Verified pointer-driven Canvas updates and the complete keyboard path for seedling placement.
- Verified every semantic control has a minimum measured target of 44 × 44 CSS pixels.
- Verified all 22 scene assets requested by the renderer loaded successfully; the provisional logo and unused generic material remain packaged but are not requested.
- Verified step confirmation advances only after a successful checkpoint response.
- Verified the final panel exposes qualitative outcomes only.
- Replaced the opaque dashboard card with the approved full-screen HUD direction and visually checked all five reference states.
- Added step-specific guides: segmented dig ring, soil-level placement axes, inward cover arrows and watering sweep ellipse.
- Corrected water absorption/pour rates after QA showed the original decay made the completion threshold unreachable; a balanced sweep now completes without requiring pooling.
- Production build uses relative Vite and asset paths for FiveM CEF.

## Integration checks

- Browser mode starts a local mock session.
- FiveM mode accepts `tomatoPlant:open`, `tomatoPlant:restore`, and `tomatoPlant:close`.
- NUI callbacks are HTTPS POSTs and report failures without resetting local progress.
- Each completed step emits a checkpoint with capped 20 Hz trace and local signals, never a direct `quality` field.

final result: passed browser validation
