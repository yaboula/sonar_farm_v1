--[[
    sonar_farm - Crop definitions (data-driven)
    The engine is crop-agnostic: it reads these tables at runtime. Adding a new
    crop never requires touching core logic.

    Schema per crop:
      label         string  Display name.
      seedItem      string  ox_inventory item consumed to plant.
      productItem   string  ox_inventory item yielded on harvest.
      growthTime    number  Seconds from planting to fully grown.
      stages        table   Visual stages picked by elapsed ratio (Stage 4 props).
                            Each: { model = 'prop_name', ratio = 0.0 .. 1.0 }.
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
        growthTime = 900,
        stages = {
            { model = 'prop_veg_crop_03', ratio = 0.0 },
            { model = 'prop_veg_crop_03b', ratio = 0.45 },
            { model = 'prop_veg_crop_orange', ratio = 1.0 },
        },
        -- Tuber: stores water underground, tolerates neglect.
        water = { decayPerHour = 12, droughtTolerance = 0.7 },
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
        growthTime = 1200,
        stages = {
            { model = 'prop_veg_crop_03', ratio = 0.0 },
            { model = 'prop_veg_crop_03b', ratio = 0.5 },
            { model = 'prop_veg_crop_04', ratio = 1.0 },
        },
        -- Hardiest of the four: slowest water decay, highest tolerance.
        water = { decayPerHour = 10, droughtTolerance = 0.8 },
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
        growthTime = 600,
        stages = {
            { model = 'prop_veg_crop_03', ratio = 0.0 },
            { model = 'prop_veg_crop_03b', ratio = 0.5 },
            { model = 'prop_veg_crop_03c', ratio = 1.0 },
        },
        -- Leafy: fast cycle but very thirsty and quick to wilt.
        water = { decayPerHour = 28, droughtTolerance = 0.2 },
        yield = { min = 2, max = 4 },
        xpReward = 8,
        requiredLevel = 0,
        spoilagePerHour = 10,
        multiHarvest = false,
    },

    tomato = {
        label = 'Tomato',
        seedItem = 'tomato_seed',
        productItem = 'tomato',
        growthTime = 1500,
        stages = {
            { model = 'prop_veg_crop_03', ratio = 0.0 },
            { model = 'prop_veg_crop_03b', ratio = 0.4 },
            { model = 'prop_veg_crop_tr_01', ratio = 1.0 },
        },
        -- Fruit: slow and demanding, the most valuable of the four.
        water = { decayPerHour = 20, droughtTolerance = 0.4 },
        yield = { min = 3, max = 6 },
        xpReward = 15,
        requiredLevel = 0,
        spoilagePerHour = 6,
        -- Reserved for a later stage; the Stage 3 harvest handler ignores this.
        multiHarvest = false,
    },
}
