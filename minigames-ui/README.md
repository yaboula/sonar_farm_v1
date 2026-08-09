# Tomato Initial Planting UI

Independent React, Vite and TypeScript package for the Stage 5.1 planting minigame. It has no runtime dependency on `web/` or the Lua/core packages.

## Commands

- `npm run dev` — browser mock session
- `npm run typecheck` — TypeScript project check
- `npm run lint` — Oxlint source check
- `npm test` — deterministic reducer, metrics, geometry, contract and trace tests
- `npm run build` — production bundle

## Runtime integration

The browser mock opens automatically outside FiveM. FiveM can post `tomatoPlant:open`, `tomatoPlant:restore`, and `tomatoPlant:close` messages. Callback names and the portable payload contract are defined in `public/contracts/tomato-plant-v1.json`.
