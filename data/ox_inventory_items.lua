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
        description = "A compact watering can rated for 20 field uses.",
        consume = 0,
    },

    ["watering_can_reinforced"] = {
        label = "Reinforced Watering Can",
        weight = 950,
        stack = false,
        close = false,
        description = "A reinforced watering can rated for 50 field uses.",
        consume = 0,
    },

    ["watering_can_professional"] = {
        label = "Professional Watering Can",
        weight = 1100,
        stack = false,
        close = false,
        description = "A professional watering can rated for 100 field uses.",
        consume = 0,
    },

    ["hand_hoe"] = {
        label = "Field Hand Hoe",
        weight = 900,
        stack = false,
        close = false,
        description = "A basic hand hoe rated for 20 uses and 55% weed removal.",
        consume = 0,
    },

    ["hand_hoe_reinforced"] = {
        label = "Reinforced Hand Hoe",
        weight = 1050,
        stack = false,
        close = false,
        description = "A reinforced hoe rated for 50 uses and 75% weed removal.",
        consume = 0,
    },

    ["hand_hoe_professional"] = {
        label = "Professional Hand Hoe",
        weight = 1200,
        stack = false,
        close = false,
        description = "A professional hoe rated for 100 uses and complete weed removal.",
        consume = 0,
    },

    ["fertilizer_organic"] = {
        label = "Organic Fertilizer",
        weight = 350,
        stack = true,
        close = false,
        description = "A gentle nutrient treatment with two hours of light retention.",
    },

    ["fertilizer_balanced"] = {
        label = "Balanced Fertilizer",
        weight = 400,
        stack = true,
        close = false,
        description = "A balanced treatment with six hours of nutrient retention.",
    },

    ["fertilizer_chemical"] = {
        label = "Professional Fertilizer",
        weight = 250,
        stack = true,
        close = false,
        description = "A concentrated treatment with twelve hours of strong retention.",
    },

    ["pest_spray_organic"] = {
        label = "Organic Pest Treatment",
        weight = 300,
        stack = true,
        close = false,
        description = "A crop-safe treatment that suppresses new pest growth for three hours.",
    },

    ["pest_spray_targeted"] = {
        label = "Targeted Pest Treatment",
        weight = 350,
        stack = true,
        close = false,
        description = "A targeted treatment with eight hours of active suppression.",
    },

    ["pest_spray_chemical"] = {
        label = "Professional Pest Treatment",
        weight = 400,
        stack = true,
        close = false,
        description = "A professional treatment with sixteen hours of strong suppression.",
    },

}
