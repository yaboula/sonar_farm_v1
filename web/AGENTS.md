# Prototype Instructions

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

Build app UI in `src/`. Keep `.openai/hosting.json`, `worker/index.js`, `scripts/prepare-sites-build.mjs`, and `tests/sites-worker.test.mjs` intact so the same local prototype can be handed to Sites. Before a Sites handoff, run `npm run build` and `npm run test:sites`; the build must leave `dist/client/index.html`, `dist/server/index.js`, and `dist/.openai/hosting.json`.

## Durable Sonar Farm decisions

- The product canvas is a fixed logical 1440 x 810 surface and is always opaque.
- The FiveM world may be visible only outside the physical Office Terminal or Farm Tablet shell. Never reveal the world through the product canvas.
- Office and Tablet use the same routes and view components. Only the physical shell, surface label, and capabilities change.
- The Office frame must never cover or crop the logical canvas. Decorative frame art is restricted to the area outside the 1440 x 810 screen.
- The approved Today screenshot at `D:/Descargas/ChatGPT Image 8 ago 2026, 16_15_37.png` is the visual source of truth for hierarchy, density, typography, and tone.
- Use Barlow Condensed for display/UI headings, Source Sans 3 for body copy, Phosphor for interface icons, warm yellow for action/selection, and opaque charcoal surfaces.
- Keep the developer role/surface/state controls behind `import.meta.env.DEV`; they must not ship in the FiveM production build.
- Phase 1 contains Today, Fields, Work, Supplies, and Company hubs. Phase 2 adds one deep frontend view at a time while backend/Lua integration, real payments, persistence, and minigames remain out of scope.
- Assignment Detail is the first Phase 2 view. Its master state is Worker + In Progress; `Resume Field Work` requests a world handoff and never fabricates verified progress.
- Worker and Supervisor are the explicit Assignment Detail perspectives. Manager and Owner inherit Supervisor behavior until dedicated variants are designed.
- Deep-view actions come from adapter-provided `availableActions`; components do not infer business rules from role labels or status copy.
- Product selection controls use the reusable `FarmSelect` component. Never expose the operating system's native select popup inside the Sonar Farm product UI.
- Field operating maps use a fixed 0° Row grid with no zoom or free pan. The map owns a vertical scroll viewport showing 10 Rows at a time; selecting a Row reveals up to 20 Slots across the same fixed-width rectangle.
- Each Field Row owns an independent, authoritative topology of 2–20 Slots. The UI must use stable Slot IDs and each Row's `slotIds`; it must never assume that adjacent Rows have equal Slot counts.
