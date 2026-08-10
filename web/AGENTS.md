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
- Sonar Farm is the immutable system brand; Grapeseed Farm Co. is the mutable player-company fixture.
- Company is the authority for Treasury, Warehouse, Staff, Leases, identity and ownership. Work and Supplies publish final money movements into Company instead of maintaining independent balances.
- Surface (`office` or `tablet`) and presence (`remote`, `office`, `warehouse`, `registry`) are independent. Physical mutations must be derived from adapter-provided actions after both are evaluated.
- Runtime role transitions preserve `actorId`. Only the development preview role selector swaps to a different fixture actor.
- Business Sale transfers the complete company atomically through buyer escrow and Registry confirmations; Staff, Warehouse and Treasury remain with the company while the former Owner exits.
- Field operating maps use a fixed 0° Row grid with no zoom or free pan. The map owns a vertical scroll viewport showing 10 Rows at a time; selecting a Row reveals up to 20 Slots across the same fixed-width rectangle.
- Each Field Row owns an independent, authoritative topology of 2–20 Slots. The UI must use stable Slot IDs and each Row's `slotIds`; it must never assume that adjacent Rows have equal Slot counts.
- The five `temp/general_reference_*.png` Tomato Initial Planting screens are the minigame's visual source of truth. Preserve their full-screen HUD composition, large central soil diorama, top-left crop identity, centered four-step rail, left Tools palette, right Materials palette, bottom gesture instruction, restrained warm-yellow guidance, and near-black world backdrop.
- Minigame UI must feel embedded in the field rather than placed inside an opaque dashboard card. Do not reuse the Business Hub shell, header/footer bars, compact centered panel, or dashboard result cards for planting gameplay.
- The planting result keeps the same spatial HUD and soil diorama, replacing tool/material inventories with four qualitative condition summaries around the established seedling.
- Inside FiveM, Business Hub data and mutations come exclusively from `NuiHubAdapter`; `FixtureHubAdapter` is limited to browser, Sites, tests, and visual development. Unimplemented runtime routes render `unavailable`, never plausible fixture data.
- Company Treasury is the only Supplies payer. Tablet may browse, draft, and request approval; only the physically validated Office Terminal may confirm an order, and only the physical Warehouse may withdraw or return materials.
- MySQL Field topology is authoritative in runtime. `Config.FieldSeeds` is an idempotent, version-controlled import source; changed geometry creates a draft revision and never overwrites an active revision.
- Land is permanent Company property, never a recurring lease. Company bootstrap atomically receives one available Starter Field; Manager prepares a paid acquisition and only Owner confirms it at the physical Office.
- Crop Plans reserve exact stable Row IDs. Company farming authority requires structured Assignment or Contract Work even for Owner and Manager; prose never advances progress.
- Worker and Contractor Field views are restricted to their active Work Rows. Company Cargo remains Company-owned from harvest through physical Warehouse deposit, and produce lots remain separated by quality, production and defects.
- Supply item art uses one matte 3D clay/cartoon language with isometric three-quarter camera, warm agricultural light, transparent RGBA background, and no text, logo, frame, or floor. Basic uses kraft/soil/muted green, Plus agricultural teal/blue, and Pro warm orange/brass.
- Crop inspection uses the approved Pulse Rail reference at `C:/Users/aboul/AppData/Local/Temp/codex-clipboard-908dece2-35e5-4ef0-89eb-28b30b95c287.png`: a slim horizontal agronomic HUD from the right edge of the minimap to the screen safe edge. Preserve compact columns, real temporal curves, matte charcoal surfaces, warm-yellow diagnosis, and non-interactive recommendation. It never takes NUI focus.
