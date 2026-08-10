--[[
    sonar_farm - Canonical item and supplier catalog

    This is the only authored source for inventory definitions, supplier
    pricing and Advanced Crop Care effects. data/ox_inventory_items.lua is a
    generated installation snapshot; run `lua scripts/generate_items.lua` after
    changing this file and `lua scripts/generate_items.lua --check` in CI.
]]

Sonar = Sonar or {}

local items = {
    { id = 'carrot_seed', label = 'Carrot Seeds', weight = 10, stack = true, category = 'Seeds', tier = 'basic', price = 24, leadMinutes = 5, market = true, cropRelation = 'Carrots', description = 'A packet of reliable carrot seed for direct field sowing.', seed = true },
    { id = 'potato_seed', label = 'Potato Seeds', weight = 10, stack = true, category = 'Seeds', tier = 'basic', price = 28, leadMinutes = 5, market = true, cropRelation = 'Potatoes', description = 'Selected seed potatoes prepared for field planting.', seed = true },
    { id = 'lettuce_seed', label = 'Lettuce Seeds', weight = 8, stack = true, category = 'Seeds', tier = 'basic', price = 22, leadMinutes = 5, market = true, cropRelation = 'Lettuce', description = 'Fast-growing lettuce seed that rewards careful watering.', seed = true },
    { id = 'tomato_seed', label = 'Tomato Seeds (Legacy)', weight = 10, stack = true, category = 'Seeds', tier = 'basic', market = false, legacy = true, cropRelation = 'Tomatoes', description = 'Legacy tomato seed stock retained for inventory compatibility.' },
    { id = 'tomato_seedling', label = 'Tomato Seedling', weight = 180, stack = true, category = 'Seedlings', tier = 'basic', price = 45, leadMinutes = 5, market = true, cropRelation = 'Tomatoes', description = 'A nursery-grown tomato transplant ready for careful field planting.', seed = true },

    { id = 'carrot', label = 'Carrot', weight = 120, stack = true, category = 'Produce', market = false, description = 'A freshly harvested carrot.' },
    { id = 'potato', label = 'Potato', weight = 150, stack = true, category = 'Produce', market = false, description = 'A freshly harvested potato.' },
    { id = 'lettuce', label = 'Lettuce', weight = 100, stack = true, category = 'Produce', market = false, description = 'A freshly harvested lettuce.' },
    { id = 'tomato', label = 'Tomato', weight = 110, stack = true, category = 'Produce', market = false, description = 'A freshly harvested tomato.' },

    { id = 'watering_can', label = 'Field Watering Can', weight = 800, stack = false, category = 'Watering', tier = 'basic', price = 180, leadMinutes = 5, market = true, cropRelation = 'All crops', description = 'A compact watering can that restores +40% water (20 field uses).', tool = { action = 'water', uses = 20, amount = 40, protectionStrength = 0.0, protectionHours = 0 } },
    { id = 'watering_can_reinforced', label = 'Reinforced Watering Can', weight = 950, stack = false, category = 'Watering', tier = 'plus', price = 380, leadMinutes = 10, market = true, cropRelation = 'All crops', description = 'Restores +70% water with 8 minutes of 40% soil moisture retention (50 uses).', tool = { action = 'water', uses = 50, amount = 70, protectionStrength = 0.40, protectionHours = 0.133 } },
    { id = 'watering_can_professional', label = 'Professional Watering Can', weight = 1100, stack = false, category = 'Watering', tier = 'pro', price = 650, leadMinutes = 15, market = true, cropRelation = 'All crops', description = 'Restores +100% water with 15 minutes of 75% soil moisture retention (100 uses).', tool = { action = 'water', uses = 100, amount = 100, protectionStrength = 0.75, protectionHours = 0.25 } },

    { id = 'hand_hoe', label = 'Field Hand Hoe', weight = 900, stack = false, category = 'Hand Tools', tier = 'basic', price = 140, leadMinutes = 5, market = true, cropRelation = 'All crops', description = 'Basic hoe for 55% weed removal (20 uses).', tool = { action = 'weed', uses = 20, weedRemoval = 55, protectionStrength = 0.0, protectionHours = 0 } },
    { id = 'hand_hoe_reinforced', label = 'Reinforced Hand Hoe', weight = 1050, stack = false, category = 'Hand Tools', tier = 'plus', price = 320, leadMinutes = 10, market = true, cropRelation = 'All crops', description = 'Reinforced hoe for 80% weed removal with 5m of 40% weed resistance (50 uses).', tool = { action = 'weed', uses = 50, weedRemoval = 80, protectionStrength = 0.40, protectionHours = 0.083 } },
    { id = 'hand_hoe_professional', label = 'Professional Hand Hoe', weight = 1200, stack = false, category = 'Hand Tools', tier = 'pro', price = 560, leadMinutes = 15, market = true, cropRelation = 'All crops', description = 'Professional hoe for 100% weed removal with 12m of 80% weed resistance (100 uses).', tool = { action = 'weed', uses = 100, weedRemoval = 100, protectionStrength = 0.80, protectionHours = 0.20 } },

    { id = 'fertilizer_organic', label = 'Organic Fertilizer', weight = 350, stack = true, category = 'Fertilizer', tier = 'basic', price = 35, leadMinutes = 5, market = true, cropRelation = 'All crops', description = 'Gentle fertilizer (+25% nutrients) with 4 minutes of 20% retention.', consumable = { action = 'fertilize', amount = 25, protectionStrength = 0.20, protectionHours = 0.067, burnMultiplier = 0.25 } },
    { id = 'fertilizer_balanced', label = 'Balanced Fertilizer', weight = 400, stack = true, category = 'Fertilizer', tier = 'plus', price = 80, leadMinutes = 10, market = true, cropRelation = 'All crops', description = 'Balanced treatment (+40% nutrients) with 10 minutes of 45% retention.', consumable = { action = 'fertilize', amount = 40, protectionStrength = 0.45, protectionHours = 0.167, burnMultiplier = 0.40 } },
    { id = 'fertilizer_chemical', label = 'Professional Fertilizer', weight = 250, stack = true, category = 'Fertilizer', tier = 'pro', price = 150, leadMinutes = 15, market = true, cropRelation = 'All crops', description = 'Concentrated treatment (+60% nutrients) with 18 minutes of 75% retention.', consumable = { action = 'fertilize', amount = 60, protectionStrength = 0.75, protectionHours = 0.30, burnMultiplier = 0.75 } },

    { id = 'pest_spray_organic', label = 'Organic Pest Treatment', weight = 300, stack = true, category = 'Pest Treatment', tier = 'basic', price = 40, leadMinutes = 5, market = true, cropRelation = 'All crops', description = 'Crop-safe treatment (-40% pests) with 4 minutes of 30% pest suppression.', consumable = { action = 'treat_pest', reduction = 40, protectionStrength = 0.30, protectionHours = 0.067 } },
    { id = 'pest_spray_targeted', label = 'Targeted Pest Treatment', weight = 350, stack = true, category = 'Pest Treatment', tier = 'plus', price = 90, leadMinutes = 10, market = true, cropRelation = 'All crops', description = 'Targeted treatment (-70% pests) with 10 minutes of 60% pest suppression.', consumable = { action = 'treat_pest', reduction = 70, protectionStrength = 0.60, protectionHours = 0.167 } },
    { id = 'pest_spray_chemical', label = 'Professional Pest Treatment', weight = 400, stack = true, category = 'Pest Treatment', tier = 'pro', price = 170, leadMinutes = 15, market = true, cropRelation = 'All crops', description = 'Professional treatment (-100% pests) with 18 minutes of 90% pest suppression.', consumable = { action = 'treat_pest', reduction = 100, protectionStrength = 0.90, protectionHours = 0.30 } },
}

local byId, market = {}, {}
for _, item in ipairs(items) do
    assert(not byId[item.id], ('Duplicate item id: %s'):format(item.id))
    byId[item.id] = item
    if item.market then market[#market + 1] = item end
end

Sonar.ItemCatalog = {
    version = 1,
    items = items,
    byId = byId,
    market = market,
    tiers = { basic = 1, plus = 2, pro = 3 },
}
