--[[
    sonar_farm - Public farming zones (data-driven)
    MVP uses public, delimited zones. Private plots / properties arrive in Phase 2.

    NOTE: Placeholder schema for Stage 1. Zone loading, spatial hashing and
    culling are implemented in Stage 4.

    Schema per zone:
      label      string   Display name (English).
      center     vector3  Zone center.
      radius     number   Zone radius in meters.
      allowedCrops table  List of crop keys plantable here (empty = all).
      cellSize   number   Spatial-hash cell size in meters (default 100).
]]

Config.Zones = {
    -- Example (disabled until Stage 4):
    -- grapeseed_fields = {
    --     label = 'Grapeseed Fields',
    --     center = vec3(2260.0, 4880.0, 41.0),
    --     radius = 120.0,
    --     allowedCrops = {},
    --     cellSize = 100,
    -- },
}
