-- GENERATED FILE - DO NOT EDIT.
-- Source: shared/item_catalog.lua
-- Run: lua scripts/generate_items.lua

return {
    ["carrot_seed"] = {
        label = "Carrot Seeds",
        weight = 10,
        stack = true,
        close = true,
        description = "A packet of reliable carrot seed for direct field sowing.",
        client = {
            export = 'sonar_farm.useSeed',
        },
    },

    ["potato_seed"] = {
        label = "Potato Seeds",
        weight = 10,
        stack = true,
        close = true,
        description = "Selected seed potatoes prepared for field planting.",
        client = {
            export = 'sonar_farm.useSeed',
        },
    },

    ["lettuce_seed"] = {
        label = "Lettuce Seeds",
        weight = 8,
        stack = true,
        close = true,
        description = "Fast-growing lettuce seed that rewards careful watering.",
        client = {
            export = 'sonar_farm.useSeed',
        },
    },

    ["tomato_seed"] = {
        label = "Tomato Seeds (Legacy)",
        weight = 10,
        stack = true,
        close = false,
        description = "Legacy tomato seed stock retained for inventory compatibility.",
    },

    ["tomato_seedling"] = {
        label = "Tomato Seedling",
        weight = 180,
        stack = true,
        close = true,
        description = "A nursery-grown tomato transplant ready for careful field planting.",
        client = {
            export = 'sonar_farm.useSeed',
        },
    },

    ["carrot"] = {
        label = "Carrot",
        weight = 120,
        stack = true,
        close = false,
        description = "A freshly harvested carrot.",
    },

    ["potato"] = {
        label = "Potato",
        weight = 150,
        stack = true,
        close = false,
        description = "A freshly harvested potato.",
    },

    ["lettuce"] = {
        label = "Lettuce",
        weight = 100,
        stack = true,
        close = false,
        description = "A freshly harvested lettuce.",
    },

    ["tomato"] = {
        label = "Tomato",
        weight = 110,
        stack = true,
        close = false,
        description = "A freshly harvested tomato.",
    },

    ["watering_can"] = {
        label = "Field Watering Can",
        weight = 800,
        stack = false,
        close = false,
        description = "A compact watering can that restores +40% water (20 field uses).",
        consume = 0,
    },

    ["watering_can_reinforced"] = {
        label = "Reinforced Watering Can",
        weight = 950,
        stack = false,
        close = false,
        description = "Restores +70% water with 8 minutes of 40% soil moisture retention (50 uses).",
        consume = 0,
    },

    ["watering_can_professional"] = {
        label = "Professional Watering Can",
        weight = 1100,
        stack = false,
        close = false,
        description = "Restores +100% water with 15 minutes of 75% soil moisture retention (100 uses).",
        consume = 0,
    },

    ["hand_hoe"] = {
        label = "Field Hand Hoe",
        weight = 900,
        stack = false,
        close = false,
        description = "Basic hoe for 55% weed removal (20 uses).",
        consume = 0,
    },

    ["hand_hoe_reinforced"] = {
        label = "Reinforced Hand Hoe",
        weight = 1050,
        stack = false,
        close = false,
        description = "Reinforced hoe for 80% weed removal with 5m of 40% weed resistance (50 uses).",
        consume = 0,
    },

    ["hand_hoe_professional"] = {
        label = "Professional Hand Hoe",
        weight = 1200,
        stack = false,
        close = false,
        description = "Professional hoe for 100% weed removal with 12m of 80% weed resistance (100 uses).",
        consume = 0,
    },

    ["fertilizer_organic"] = {
        label = "Organic Fertilizer",
        weight = 350,
        stack = true,
        close = false,
        description = "Gentle fertilizer (+25% nutrients) with 4 minutes of 20% retention.",
    },

    ["fertilizer_balanced"] = {
        label = "Balanced Fertilizer",
        weight = 400,
        stack = true,
        close = false,
        description = "Balanced treatment (+40% nutrients) with 10 minutes of 45% retention.",
    },

    ["fertilizer_chemical"] = {
        label = "Professional Fertilizer",
        weight = 250,
        stack = true,
        close = false,
        description = "Concentrated treatment (+60% nutrients) with 18 minutes of 75% retention.",
    },

    ["pest_spray_organic"] = {
        label = "Organic Pest Treatment",
        weight = 300,
        stack = true,
        close = false,
        description = "Crop-safe treatment (-40% pests) with 4 minutes of 30% pest suppression.",
    },

    ["pest_spray_targeted"] = {
        label = "Targeted Pest Treatment",
        weight = 350,
        stack = true,
        close = false,
        description = "Targeted treatment (-70% pests) with 10 minutes of 60% pest suppression.",
    },

    ["pest_spray_chemical"] = {
        label = "Professional Pest Treatment",
        weight = 400,
        stack = true,
        close = false,
        description = "Professional treatment (-100% pests) with 18 minutes of 90% pest suppression.",
    },

}
