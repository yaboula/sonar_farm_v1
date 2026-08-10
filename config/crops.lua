--[[
    sonar_farm - Crop definitions (data-driven)
    The engine is crop-agnostic: it reads these tables at runtime. Adding a new
    crop never requires touching core logic.

    Schema per crop:
      label         string  Display name.
      seedItem      string  ox_inventory item consumed to plant.
      productItem   string  ox_inventory item yielded on harvest.
      growthTime    number  Seconds from planting to fully grown.
      cycle         table   V2 rates expressed per complete growth cycle.
      stages        table   Visual stages picked by elapsed ratio (Stage 4 props).
                            Each: { model = 'prop_name', ratio = 0.0 .. 1.0 }.
                            Models come from the custom plant pack, which must be
                            running as its own resource. Every model is checked
                            with IsModelValid at boot: missing ones are reported
                            by name in the console and fall back to
                            Config.Render.FallbackModel, so a wrong name is
                            obvious instead of silently rendering nothing.
      water         table   Physiology:
                              decayPerHour  water points lost per hour (0..100 scale)
                              droughtTolerance  0..1, dampens health loss when dry
      yield         table   { min, max } base units before quality scaling.
      xpReward      number  Base XP on harvest (consumed in Stage 7).
      requiredLevel number  Farming level required to plant (Stage 7).
      spoilagePerHour number Quality lost per hour once mature and unharvested.
      multiHarvest  boolean DOCUMENTED BUT INACTIVE in Stage 3. Reserved for
                            fruiting crops that yield repeatedly (later stage).

    Physiology is deliberately differentiated so the four MVP crops exercise
    different code paths: tubers resist drought, leafy crops are fast and
    fragile, fruits are slow and valuable.
]]

Config.Crops = {
    carrot = {
        label = 'Carrot',
        seedItem = 'carrot_seed',
        productItem = 'carrot',
        growthTime = 1800,
        stages = {
            { model = 'bzzz_plants_carrot_01', ratio = 0.0, label = 'Establishing' },
            { model = 'bzzz_plants_carrot_02', ratio = 0.45, label = 'Root development' },
            { model = 'bzzz_plants_carrot_03', ratio = 1.0, label = 'Harvest ready' },
        },
        -- Tuber: stores water underground, tolerates neglect.
        water = { decayPerHour = 120, droughtTolerance = 0.7 },
        nutrients = { decayPerHour = 100, optimalMin = 42, optimalMax = 82, overfertilizeCeiling = 100 },
        weeds = { growthPerHour = 180, resistance = 0.55 },
        pests = { onsetHours = 0.15, susceptibility = 0.35 },
        cycle = { waterLoss = 280, nutrientLoss = 175, weedGrowth = 350,
            pestOnset = 0.18, pestGrowth = 220, spoilage = 50, droughtTolerance = 0.85 },
        criticalWindow = { from = 0.35, to = 0.68 },
        yield = { min = 2, max = 5 },
        xpReward = 10,
        requiredLevel = 0,
        spoilagePerHour = 4,
        multiHarvest = false,
    },

    potato = {
        label = 'Potato',
        seedItem = 'potato_seed',
        productItem = 'potato',
        growthTime = 2100,
        stages = {
            { model = 'bzzz_plants_potato_01', ratio = 0.0, label = 'Sprouting' },
            { model = 'bzzz_plants_potato_02', ratio = 0.5, label = 'Tuber bulking' },
            { model = 'bzzz_plants_potato_03', ratio = 1.0, label = 'Harvest ready' },
        },
        -- Hardiest of the four: slowest water decay, highest tolerance.
        water = { decayPerHour = 100, droughtTolerance = 0.8 },
        nutrients = { decayPerHour = 80, optimalMin = 36, optimalMax = 85, overfertilizeCeiling = 100 },
        weeds = { growthPerHour = 150, resistance = 0.7 },
        pests = { onsetHours = 0.20, susceptibility = 0.2 },
        cycle = { waterLoss = 240, nutrientLoss = 160, weedGrowth = 300,
            pestOnset = 0.25, pestGrowth = 160, spoilage = 35, droughtTolerance = 0.9 },
        criticalWindow = { from = 0.25, to = 0.72 },
        yield = { min = 3, max = 7 },
        xpReward = 12,
        requiredLevel = 0,
        spoilagePerHour = 3,
        multiHarvest = false,
    },

    lettuce = {
        label = 'Lettuce',
        seedItem = 'lettuce_seed',
        productItem = 'lettuce',
        growthTime = 1200,
        stages = {
            { model = 'bzzz_plants_lettuce_01', ratio = 0.0, label = 'Seedling' },
            { model = 'bzzz_plants_lettuce_02', ratio = 0.5, label = 'Head formation' },
            { model = 'bzzz_plants_lettuce_03', ratio = 1.0, label = 'Harvest ready' },
        },
        -- Leafy: fast cycle but very thirsty and quick to wilt.
        water = { decayPerHour = 280, droughtTolerance = 0.2 },
        nutrients = { decayPerHour = 220, optimalMin = 55, optimalMax = 82, overfertilizeCeiling = 100 },
        weeds = { growthPerHour = 280, resistance = 0.15 },
        pests = { onsetHours = 0.08, susceptibility = 0.8 },
        cycle = { waterLoss = 320, nutrientLoss = 190, weedGrowth = 420,
            pestOnset = 0.08, pestGrowth = 450, spoilage = 90 },
        criticalWindow = { from = 0.18, to = 0.62 },
        yield = { min = 2, max = 4 },
        xpReward = 8,
        requiredLevel = 0,
        spoilagePerHour = 10,
        multiHarvest = false,
    },

    tomato = {
        label = 'Tomato',
        seedItem = 'tomato_seedling',
        legacySeedItem = 'tomato_seed',
        requiresMinigame = true,
        productItem = 'tomato',
        growthTime = 2400,
        stages = {
            { model = 'bzzz_plants_tomato_01', ratio = 0.0, label = 'Establishing' },
            { model = 'bzzz_plants_tomato_02', ratio = 0.4, label = 'Flowering' },
            { model = 'bzzz_plants_tomato_03', ratio = 1.0, label = 'Harvest ready' },
        },
        -- Fruit: slow and demanding, the most valuable of the four.
        water = { decayPerHour = 220, droughtTolerance = 0.4 },
        nutrients = { decayPerHour = 180, optimalMin = 52, optimalMax = 78, overfertilizeCeiling = 100 },
        weeds = { growthPerHour = 220, resistance = 0.3 },
        pests = { onsetHours = 0.15, susceptibility = 0.9 },
        cycle = { waterLoss = 300, nutrientLoss = 180, weedGrowth = 400,
            pestOnset = 0.12, pestGrowth = 380, spoilage = 65 },
        criticalWindow = { from = 0.38, to = 0.72 },
        conditionEffects = { weeds = true, pests = true },
        yield = { min = 3, max = 6 },
        xpReward = 15,
        requiredLevel = 0,
        spoilagePerHour = 6,
        -- Reserved for a later stage; the Stage 3 harvest handler ignores this.
        multiHarvest = false,
    },
}
