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
]]

return {
    -- -----------------------------------------------------------------------
    -- SEEDS (consumed on plant)
    -- -----------------------------------------------------------------------

    ['carrot_seed'] = {
        label = 'Carrot Seeds',
        weight = 10,
        stack = true,
        close = false,
        description = 'A handful of carrot seeds. Plant them in a farming zone.',
    },

    ['potato_seed'] = {
        label = 'Potato Seeds',
        weight = 10,
        stack = true,
        close = false,
        description = 'Seed potatoes. Hardy and forgiving of dry soil.',
    },

    ['lettuce_seed'] = {
        label = 'Lettuce Seeds',
        weight = 8,
        stack = true,
        close = false,
        description = 'Lettuce seeds. Fast growing but very thirsty.',
    },

    ['tomato_seed'] = {
        label = 'Tomato Seeds',
        weight = 10,
        stack = true,
        close = false,
        description = 'Tomato seeds. Slow to ripen, worth the wait.',
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
}
