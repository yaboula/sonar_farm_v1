--[[
    sonar_farm - Crop definitions (data-driven)
    The engine is crop-agnostic: it reads these tables at runtime. Adding a new
    crop should never require touching core logic.

    NOTE: This is a placeholder schema for Stage 1. Growth logic, physiology
    (watering / health / spoilage) and quality are implemented from Stage 3+.
    Fields are documented here so the shape is stable across the project.

    Schema per crop:
      label        string   Display name (English).
      seedItem     string   ox_inventory item planted to start the crop.
      productItem  string   ox_inventory item yielded on harvest.
      growthTime   number   Total seconds from planting to fully grown.
      stages       table    Visual stages (props), evaluated by elapsed ratio.
                            Each: { model = 'prop_name', ratio = 0.0 .. 1.0 }.
      water        table    { needed = bool, interval = seconds } (Stage 3+).
      yield        table    { min = number, max = number } base yield range.
      xpReward     number   Base XP granted on harvest.
      requiredLevel number  Farming level required to plant.
]]

Config.Crops = {
    -- Example (disabled until Stage 3 wires the full lifecycle):
    -- carrot = {
    --     label = 'Carrot',
    --     seedItem = 'carrot_seed',
    --     productItem = 'carrot',
    --     growthTime = 600,
    --     stages = {
    --         { model = 'prop_veg_crop_03', ratio = 0.0 },
    --         { model = 'prop_veg_crop_03b', ratio = 0.5 },
    --         { model = 'prop_veg_crop_tr', ratio = 1.0 },
    --     },
    --     water = { needed = true, interval = 120 },
    --     yield = { min = 2, max = 5 },
    --     xpReward = 10,
    --     requiredLevel = 0,
    -- },
}
