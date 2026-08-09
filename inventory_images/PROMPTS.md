# Sonar Farm item art prompt set

All 21 items were generated individually with the built-in ImageGen path using the `stylized-concept` use case.

Shared production prompt: polished 3D clay/cartoon farming-game inventory object; chunky readable silhouette; matte opaque materials; centered 3/4 isometric view; warm agricultural subject lighting; no text, brand, frame, floor, reflection or shadow; complete object within the central 80%; flat `#ff00ff` chroma backdrop removed locally to alpha.

- Basic: kraft tan, earth brown and muted sage green.
- Plus: agricultural teal, muted blue and graphite.
- Pro: warm orange, brass and graphite.
- Seeds/produce: crop-identifying natural colors while preserving the same clay material and camera.

Run `python scripts/process_item_assets.py --check` to validate names, RGBA dimensions, transparent corners, safe area, zero-alpha RGB, previews, duplicate hashes and web/ox synchronization.
