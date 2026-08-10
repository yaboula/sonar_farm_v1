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
        description = "Restores +40% water. Basic tools provide no residual protection (20 uses).",
        consume = 0,
    },

    ["watering_can_reinforced"] = {
        label = "Reinforced Watering Can",
        weight = 950,
        stack = false,
        close = false,
        description = "Restores +70% water with 50% retention for 18% of the crop cycle (50 uses).",
        consume = 0,
    },

    ["watering_can_professional"] = {
        label = "Professional Watering Can",
        weight = 1100,
        stack = false,
        close = false,
        description = "Restores +100% water with 85% retention for 40% of the crop cycle (100 uses).",
        consume = 0,
    },

    ["hand_hoe"] = {
        label = "Field Hand Hoe",
        weight = 900,
        stack = false,
        close = false,
        description = "Removes 55% weeds. Basic tools provide no residual resistance (20 uses).",
        consume = 0,
    },

    ["hand_hoe_reinforced"] = {
        label = "Reinforced Hand Hoe",
        weight = 1050,
        stack = false,
        close = false,
        description = "Removes 80% weeds with 50% resistance for 18% of the crop cycle (50 uses).",
        consume = 0,
    },

    ["hand_hoe_professional"] = {
        label = "Professional Hand Hoe",
        weight = 1200,
        stack = false,
        close = false,
        description = "Removes 100% weeds with 85% resistance for 40% of the crop cycle (100 uses).",
        consume = 0,
    },

    ["fertilizer_organic"] = {
        label = "Organic Fertilizer",
        weight = 350,
        stack = true,
        close = false,
        description = "Adds +25% nutrients with 20% retention for 6% of the crop cycle.",
    },

    ["fertilizer_balanced"] = {
        label = "Balanced Fertilizer",
        weight = 400,
        stack = true,
        close = false,
        description = "Adds +40% nutrients with 50% retention for 18% of the crop cycle.",
    },

    ["fertilizer_chemical"] = {
        label = "Professional Fertilizer",
        weight = 250,
        stack = true,
        close = false,
        description = "Adds +60% nutrients with 85% retention for 40% of the crop cycle.",
    },

    ["pest_spray_organic"] = {
        label = "Organic Pest Treatment",
        weight = 300,
        stack = true,
        close = false,
        description = "Reduces pest pressure by 40 with 20% suppression for 6% of the crop cycle.",
    },

    ["pest_spray_targeted"] = {
        label = "Targeted Pest Treatment",
        weight = 350,
        stack = true,
        close = false,
        description = "Reduces pest pressure by 70 with 55% suppression for 18% of the crop cycle.",
    },

    ["pest_spray_chemical"] = {
        label = "Professional Pest Treatment",
        weight = 400,
        stack = true,
        close = false,
        description = "Reduces pest pressure by 100 with 90% suppression for 40% of the crop cycle.",
    },

}
