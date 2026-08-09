--[[
    sonar_farm - ox_inventory item definitions

    ox_inventory does not support registering items at runtime, so these must be
    copied into your ox_inventory installation:

        ox_inventory/data/items.lua

    Copy the entries inside the table below into ox_inventory's returned table,
    then restart ox_inventory. This file is standalone-valid Lua so it can be
    syntax-checked, but it is NOT loaded by sonar_farm.

    See docs/RUNBOOK.md for the full install steps.

    NOTE: ox_inventory looks for artwork in ox_inventory/web/images/<name>.png.
    Without artwork it falls back to a placeholder, which is fine for testing.

    IMPORTANT: the `client.export` on every seed is what makes it plantable by
    using the item, which is the gesture players try first. It calls the
    `useSeed` export in sonar_farm, which resolves the crop from the item name.
    Dropping those lines does not break anything, but planting is then only
    reachable through the field menu.
]]

return {
    -- -----------------------------------------------------------------------
    -- SEEDS (consumed on plant)
    -- -----------------------------------------------------------------------

    ['carrot_seed'] = {
        label = 'Carrot Seeds',
        weight = 10,
        stack = true,
        close = true,
        description = 'A handful of carrot seeds. Plant them in a farming zone.',
        client = {
            export = 'sonar_farm.useSeed',
        },
    },

    ['potato_seed'] = {
        label = 'Potato Seeds',
        weight = 10,
        stack = true,
        close = true,
        description = 'Seed potatoes. Hardy and forgiving of dry soil.',
        client = {
            export = 'sonar_farm.useSeed',
        },
    },

    ['lettuce_seed'] = {
        label = 'Lettuce Seeds',
        weight = 8,
        stack = true,
        close = true,
        description = 'Lettuce seeds. Fast growing but very thirsty.',
        client = {
            export = 'sonar_farm.useSeed',
        },
    },

    -- Legacy inventory item retained so existing stacks remain valid. It is no
    -- longer usable for planting once Stage 5 minigames are enabled.
    ['tomato_seed'] = {
        label = 'Tomato Seeds (Legacy)',
        weight = 10,
        stack = true,
        close = false,
        description = 'Legacy tomato seed stock. Tomato planting now requires a nursery seedling.',
    },

    ['tomato_seedling'] = {
        label = 'Tomato Seedling',
        weight = 180,
        stack = true,
        close = true,
        description = 'A nursery-grown tomato transplant ready for careful field planting.',
        client = {
            export = 'sonar_farm.useSeed',
        },
    },

    -- -----------------------------------------------------------------------
    -- PRODUCE (yielded on harvest, carries quality metadata)
    -- -----------------------------------------------------------------------

    ['carrot'] = {
        label = 'Carrot',
        weight = 120,
        stack = true,
        close = false,
        description = 'Freshly harvested carrot.',
    },

    ['potato'] = {
        label = 'Potato',
        weight = 150,
        stack = true,
        close = false,
        description = 'Freshly harvested potato.',
    },

    ['lettuce'] = {
        label = 'Lettuce',
        weight = 100,
        stack = true,
        close = false,
        description = 'Freshly harvested lettuce.',
    },

    ['tomato'] = {
        label = 'Tomato',
        weight = 110,
        stack = true,
        close = false,
        description = 'Freshly harvested tomato.',
    },

    -- -----------------------------------------------------------------------
    -- TOOLS
    -- -----------------------------------------------------------------------

    ['watering_can'] = {
        label = 'Watering Can',
        weight = 800,
        stack = false,
        close = true,
        description = 'Used to water growing crops and keep them healthy.',
    },

    ['fertilizer_organic'] = {
        label = 'Organic Fertilizer',
        weight = 350,
        stack = true,
        close = true,
        description = 'A gentle nutrient treatment with a low risk of burning crops.',
    },

    ['fertilizer_chemical'] = {
        label = 'Concentrated Fertilizer',
        weight = 250,
        stack = true,
        close = true,
        description = 'Fast nutrient recovery that can burn an already-fed crop.',
    },

    ['hand_hoe'] = {
        label = 'Hand Hoe',
        weight = 900,
        stack = false,
        close = true,
        description = 'A field tool for removing weeds without disturbing the crop.',
    },

    ['pest_spray_organic'] = {
        label = 'Organic Pest Spray',
        weight = 300,
        stack = true,
        close = true,
        description = 'A moderate crop-safe treatment for active pest pressure.',
    },

    ['pest_spray_chemical'] = {
        label = 'Concentrated Pest Spray',
        weight = 300,
        stack = true,
        close = true,
        description = 'A strong treatment for severe pest pressure.',
    },
}
