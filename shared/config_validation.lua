--[[
    sonar_farm - Configuration validation (shared, pure)
    Validates structural invariants before the server accepts gameplay.
]]

Sonar = Sonar or {}

local ConfigValidation = {}

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function positive(errors, path, value, allowZero)
    local invalid = not finite(value)
        or (allowZero and value < 0)
        or (not allowZero and value <= 0)

    if invalid then
        errors[#errors + 1] = ('%s must be %s number.'):format(
            path,
            allowZero and 'a non-negative' or 'a positive'
        )
    end
end

local function nonEmptyString(errors, path, value)
    if type(value) ~= 'string' or value == '' then
        errors[#errors + 1] = path .. ' must be a non-empty string.'
    end
end

local function range(errors, path, value, minimum, maximum)
    if not finite(value) or value < minimum or value > maximum then
        errors[#errors + 1] = ('%s must be within %s..%s.'):format(path, minimum, maximum)
    end
end

local function validateFramework(errors)
    local supported = { auto = true, ['qb-core'] = true, esx = true, qbox = true }
    if not supported[Config.Framework] then
        errors[#errors + 1] = 'Config.Framework must be auto, qb-core, esx or qbox.'
    end

    if type(Config.FrameworkPriority) ~= 'table' or #Config.FrameworkPriority == 0 then
        errors[#errors + 1] = 'Config.FrameworkPriority must contain at least one framework.'
        return
    end

    local seen = {}
    for index, framework in ipairs(Config.FrameworkPriority) do
        if framework == 'auto' or not supported[framework] then
            errors[#errors + 1] = ('Config.FrameworkPriority[%d] is unsupported.'):format(index)
        elseif seen[framework] then
            errors[#errors + 1] = ('Config.FrameworkPriority contains duplicate "%s".'):format(framework)
        end
        seen[framework] = true
        nonEmptyString(
            errors,
            ('Config.FrameworkResources.%s'):format(tostring(framework)),
            Config.FrameworkResources and Config.FrameworkResources[framework]
        )
    end
end

local function validateCrops(errors)
    if type(Config.Crops) ~= 'table' or next(Config.Crops) == nil then
        errors[#errors + 1] = 'Config.Crops must contain at least one crop.'
        return
    end

    for cropType, crop in pairs(Config.Crops) do
        local path = ('Config.Crops.%s'):format(tostring(cropType))
        if type(cropType) ~= 'string' or cropType == '' then
            errors[#errors + 1] = 'Every crop key must be a non-empty string.'
        end

        if type(crop) ~= 'table' then
            errors[#errors + 1] = path .. ' must be a table.'
        else
            for _, field in ipairs({ 'label', 'seedItem', 'productItem' }) do
                if type(crop[field]) ~= 'string' or crop[field] == '' then
                    errors[#errors + 1] = ('%s.%s must be a non-empty string.'):format(path, field)
                end
            end

            positive(errors, path .. '.growthTime', crop.growthTime, false)

            if type(crop.cycle) ~= 'table' then
                errors[#errors + 1] = path .. '.cycle must be a table for simulation V2.'
            else
                for _, key in ipairs({ 'waterLoss', 'nutrientLoss', 'weedGrowth', 'pestGrowth', 'spoilage' }) do
                    positive(errors, ('%s.cycle.%s'):format(path, key), crop.cycle[key], true)
                end
                range(errors, path .. '.cycle.pestOnset', crop.cycle.pestOnset, 0, 1)
                if crop.cycle.droughtTolerance ~= nil then
                    range(errors, path .. '.cycle.droughtTolerance', crop.cycle.droughtTolerance, 0, 0.95)
                end
            end

            if type(crop.stages) ~= 'table' or #crop.stages == 0 then
                errors[#errors + 1] = path .. '.stages must contain at least one stage.'
            else
                local previous = -1
                for index, stage in ipairs(crop.stages) do
                    local stagePath = ('%s.stages[%d]'):format(path, index)
                    if type(stage.model) ~= 'string' or stage.model == '' then
                        errors[#errors + 1] = stagePath .. '.model must be a non-empty string.'
                    end
                    if type(stage.label) ~= 'string' or stage.label == '' then
                        errors[#errors + 1] = stagePath .. '.label must be a non-empty string.'
                    end
                    if not finite(stage.ratio) or stage.ratio < 0 or stage.ratio > 1 or stage.ratio < previous then
                        errors[#errors + 1] = stagePath .. '.ratio must be ordered within 0..1.'
                    else
                        previous = stage.ratio
                    end
                end
            end

            local water = crop.water
            if type(water) ~= 'table' then
                errors[#errors + 1] = path .. '.water must be a table.'
            else
                positive(errors, path .. '.water.decayPerHour', water.decayPerHour, true)
                if not finite(water.droughtTolerance)
                    or water.droughtTolerance < 0
                    or water.droughtTolerance > 1 then
                    errors[#errors + 1] = path .. '.water.droughtTolerance must be within 0..1.'
                end
            end

            local yield = crop.yield
            if type(yield) ~= 'table'
                or not finite(yield.min)
                or not finite(yield.max)
                or yield.min < 1
                or yield.max < yield.min then
                errors[#errors + 1] = path .. '.yield must define 1 <= min <= max.'
            end

            if crop.nutrients ~= nil then
                if type(crop.nutrients) ~= 'table' then
                    errors[#errors + 1] = path .. '.nutrients must be a table.'
                else
                    positive(errors, path .. '.nutrients.decayPerHour', crop.nutrients.decayPerHour, true)
                    range(errors, path .. '.nutrients.optimalMin', crop.nutrients.optimalMin, 0, 100)
                    range(errors, path .. '.nutrients.optimalMax', crop.nutrients.optimalMax, 0, 100)
                    range(errors, path .. '.nutrients.overfertilizeCeiling', crop.nutrients.overfertilizeCeiling, 0, 100)
                    if finite(crop.nutrients.optimalMin) and finite(crop.nutrients.optimalMax)
                        and crop.nutrients.optimalMin >= crop.nutrients.optimalMax then
                        errors[#errors + 1] = path .. '.nutrients requires optimalMin < optimalMax.'
                    end
                    if finite(crop.nutrients.optimalMax) and finite(crop.nutrients.overfertilizeCeiling)
                        and crop.nutrients.optimalMax >= crop.nutrients.overfertilizeCeiling then
                        errors[#errors + 1] = path .. '.nutrients requires optimalMax < overfertilizeCeiling.'
                    end
                end
            end

            if crop.weeds ~= nil then
                if type(crop.weeds) ~= 'table' then
                    errors[#errors + 1] = path .. '.weeds must be a table.'
                else
                    positive(errors, path .. '.weeds.growthPerHour', crop.weeds.growthPerHour, true)
                    range(errors, path .. '.weeds.resistance', crop.weeds.resistance, 0, 1)
                end
            end

            if crop.pests ~= nil then
                if type(crop.pests) ~= 'table' then
                    errors[#errors + 1] = path .. '.pests must be a table.'
                else
                    positive(errors, path .. '.pests.onsetHours', crop.pests.onsetHours, true)
                    range(errors, path .. '.pests.susceptibility', crop.pests.susceptibility, 0, 1)
                end
            end

            if crop.criticalWindow ~= nil then
                if type(crop.criticalWindow) ~= 'table' then
                    errors[#errors + 1] = path .. '.criticalWindow must be a table.'
                else
                    range(errors, path .. '.criticalWindow.from', crop.criticalWindow.from, 0, 1)
                    range(errors, path .. '.criticalWindow.to', crop.criticalWindow.to, 0, 1)
                    if finite(crop.criticalWindow.from) and finite(crop.criticalWindow.to)
                        and crop.criticalWindow.from >= crop.criticalWindow.to then
                        errors[#errors + 1] = path .. '.criticalWindow requires from < to.'
                    end
                end
            end

            if crop.conditionEffects ~= nil then
                if type(crop.conditionEffects) ~= 'table' then
                    errors[#errors + 1] = path .. '.conditionEffects must be a table.'
                else
                    for key, value in pairs(crop.conditionEffects) do
                        if key ~= 'nutrients' and key ~= 'weeds' and key ~= 'pests' then
                            errors[#errors + 1] = ('%s.conditionEffects.%s is unsupported.'):format(path, tostring(key))
                        elseif type(value) ~= 'boolean' then
                            errors[#errors + 1] = ('%s.conditionEffects.%s must be boolean.'):format(path, key)
                        end
                    end
                end
            end
        end
    end
end

local function validateZones(errors, warnings)
    if type(Config.Zones) ~= 'table' or next(Config.Zones) == nil then
        errors[#errors + 1] = 'Config.Zones must contain at least one zone.'
        return
    end

    local total = 0
    for zoneKey, zone in pairs(Config.Zones) do
        local path = ('Config.Zones.%s'):format(tostring(zoneKey))
        if type(zoneKey) ~= 'string' or zoneKey == '' or not zoneKey:match('^[%w_%-]+$') then
            errors[#errors + 1] = path .. ' key must contain only letters, numbers, underscores or hyphens.'
        end

        if type(zone) ~= 'table' or type(zone.label) ~= 'string' or zone.label == '' then
            errors[#errors + 1] = path .. ' must define a non-empty label.'
        else
            for _, cropType in ipairs(zone.allowedCrops or {}) do
                if not Config.Crops[cropType] then
                    errors[#errors + 1] = ('%s.allowedCrops references unknown crop "%s".')
                        :format(path, tostring(cropType))
                end
            end

            local slots = Sonar.Zones.Slots(zoneKey)
            if #slots == 0 then
                errors[#errors + 1] = path .. ' must resolve at least one slot.'
            end
            total = total + #slots

            for index, slot in ipairs(slots) do
                if not finite(slot.x) or not finite(slot.y) or not finite(slot.z) or not finite(slot.heading) then
                    errors[#errors + 1] = ('%s slot %d has invalid coordinates or heading.'):format(path, index)
                end
                for other = 1, index - 1 do
                    local candidate = slots[other]
                    local dx, dy, dz = slot.x - candidate.x, slot.y - candidate.y, slot.z - candidate.z
                    if (dx * dx + dy * dy + dz * dz) < 0.25 then
                        errors[#errors + 1] = ('%s slots %d and %d overlap.'):format(path, other, index)
                    end
                end
            end
        end
    end

    if total > 1000 then
        warnings[#warnings + 1] = ('%d target slots are configured; validate client resmon before production.'):format(total)
    end
end

local function validateMinigames(errors)
    if not Config.Features or not Config.Features.Minigames then return end

    local plant = Config.Minigames and Config.Minigames.Plant
    if type(plant) ~= 'table' then
        errors[#errors + 1] = 'Config.Minigames.Plant must be configured when minigames are enabled.'
        return
    end

    for cropType, crop in pairs(Config.Crops or {}) do
        if crop.requiresMinigame then
            local cfg = plant[cropType]
            local path = ('Config.Minigames.Plant.%s'):format(cropType)
            if type(cfg) ~= 'table' then
                errors[#errors + 1] = path .. ' must exist for requiresMinigame crops.'
            else
                nonEmptyString(errors, path .. '.key', cfg.key)
                nonEmptyString(errors, path .. '.contractVersion', cfg.contractVersion)
                positive(errors, path .. '.sessionTtl', cfg.sessionTtl, false)
                positive(errors, path .. '.incompleteTtl', cfg.incompleteTtl, false)
                positive(errors, path .. '.maxSamplesPerStep', cfg.maxSamplesPerStep, false)
                positive(errors, path .. '.maxPayloadBytes', cfg.maxPayloadBytes, false)
                positive(errors, path .. '.sampleIntervalMs', cfg.sampleIntervalMs, false)
                positive(errors, path .. '.maximumStepDurationMs', cfg.maximumStepDurationMs, false)

                local total = 0
                for _, step in ipairs({ 'prepare', 'place', 'cover', 'water' }) do
                    local weight = cfg.stepWeights and cfg.stepWeights[step]
                    if not finite(weight) or weight <= 0 then
                        errors[#errors + 1] = ('%s.stepWeights.%s must be positive.'):format(path, step)
                    else
                        total = total + weight
                    end
                    positive(
                        errors,
                        ('%s.minimumStepDurationMs.%s'):format(path, step),
                        cfg.minimumStepDurationMs and cfg.minimumStepDurationMs[step],
                        false
                    )
                end
                if math.abs(total - 1) > 0.001 then
                    errors[#errors + 1] = path .. '.stepWeights must sum to 1.'
                end
            end
        end
    end
end

local function validateAdvancedCare(errors)
    local farming = Config.Farming
    if type(farming) ~= 'table' then
        errors[#errors + 1] = 'Config.Farming must be a table.'
        return
    end
    if not finite(farming.NewCropSimulationVersion)
        or farming.NewCropSimulationVersion < 1
        or farming.NewCropSimulationVersion % 1 ~= 0 then
        errors[#errors + 1] = 'Config.Farming.NewCropSimulationVersion must be a positive integer.'
    end

    if type(farming.ConditionEffects) ~= 'table' then
        errors[#errors + 1] = 'Config.Farming.ConditionEffects must be a table.'
    else
        for _, key in ipairs({ 'Nutrients', 'Weeds', 'Pests' }) do
            if type(farming.ConditionEffects[key]) ~= 'boolean' then
                errors[#errors + 1] = ('Config.Farming.ConditionEffects.%s must be boolean.'):format(key)
            end
        end
    end

    for _, action in ipairs({ 'fertilize', 'weed', 'treat_pest' }) do
        positive(errors, ('Config.Cooldowns.%s'):format(action), Config.Cooldowns and Config.Cooldowns[action], false)
    end

    local advanced = farming.AdvancedCare
    if type(advanced) ~= 'table' then
        errors[#errors + 1] = 'Config.Farming.AdvancedCare must be a table.'
        return
    end

    range(errors, 'Config.Farming.AdvancedCare.WaterDeficitThreshold', advanced.WaterDeficitThreshold, 0, 100)
    if not finite(advanced.CriticalStressMultiplier) or advanced.CriticalStressMultiplier < 1 then
        errors[#errors + 1] = 'Config.Farming.AdvancedCare.CriticalStressMultiplier must be at least 1.'
    end
    for _, key in ipairs({
        'WeedWaterCompetition', 'WeedNutrientCompetition', 'PestWeedAcceleration',
        'PestGrowthPerHour', 'PestDamagePerHour', 'NutrientHealthLossPerHour',
    }) do
        positive(errors, ('Config.Farming.AdvancedCare.%s'):format(key), advanced[key], true)
    end
    range(errors, 'Config.Farming.AdvancedCare.MinimumWeedCover', advanced.MinimumWeedCover, 0, 100)
    range(errors, 'Config.Farming.AdvancedCare.MinimumPestPressure', advanced.MinimumPestPressure, 0, 100)

    local penalties = advanced.GrowthPenaltyPerDeficitHour
    if type(penalties) ~= 'table' then
        errors[#errors + 1] = 'Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour must be a table.'
    else
        range(errors, 'Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour.water', penalties.water, 0, 1)
        range(errors, 'Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour.nutrients', penalties.nutrients, 0, 1)
        if finite(penalties.water) and finite(penalties.nutrients)
            and penalties.water + penalties.nutrients > 1 then
            errors[#errors + 1] = 'Config.Farming.AdvancedCare growth penalty rates must sum to at most 1.'
        end
    end

    local stress = advanced.StressPerDeficitHour
    if type(stress) ~= 'table' then
        errors[#errors + 1] = 'Config.Farming.AdvancedCare.StressPerDeficitHour must be a table.'
    else
        positive(errors, 'Config.Farming.AdvancedCare.StressPerDeficitHour.water', stress.water, true)
        positive(errors, 'Config.Farming.AdvancedCare.StressPerDeficitHour.nutrients', stress.nutrients, true)
    end

    local cycle = advanced.Cycle
    if type(cycle) ~= 'table' then
        errors[#errors + 1] = 'Config.Farming.AdvancedCare.Cycle must be a table.'
    else
        for _, key in ipairs({ 'GreenGrowthBonus', 'WatchGrowthPenalty', 'CriticalGrowthPenalty',
            'WatchStressMultiplier', 'WeedWaterCompetition', 'WeedNutrientCompetition',
            'PestWeedAcceleration' }) do
            range(errors, ('Config.Farming.AdvancedCare.Cycle.%s'):format(key), cycle[key], 0, 1)
        end
        for _, key in ipairs({ 'DryHealthLossPerCycle', 'NutrientHealthLossPerCycle', 'PestDamagePerCycle' }) do
            positive(errors, ('Config.Farming.AdvancedCare.Cycle.%s'):format(key), cycle[key], true)
        end
        positive(errors, 'Config.Farming.AdvancedCare.Cycle.StressPerCycle.water',
            cycle.StressPerCycle and cycle.StressPerCycle.water, true)
        positive(errors, 'Config.Farming.AdvancedCare.Cycle.StressPerCycle.nutrients',
            cycle.StressPerCycle and cycle.StressPerCycle.nutrients, true)
        range(errors, 'Config.Farming.AdvancedCare.Cycle.Water.green', cycle.Water and cycle.Water.green, 0, 100)
        range(errors, 'Config.Farming.AdvancedCare.Cycle.Water.critical', cycle.Water and cycle.Water.critical, 0, 100)
        range(errors, 'Config.Farming.AdvancedCare.Cycle.Pressure.green', cycle.Pressure and cycle.Pressure.green, 0, 100)
        range(errors, 'Config.Farming.AdvancedCare.Cycle.Pressure.critical', cycle.Pressure and cycle.Pressure.critical, 0, 100)
        positive(errors, 'Config.Farming.AdvancedCare.Cycle.NutrientWatchMargin', cycle.NutrientWatchMargin, true)
    end

    local catalog = Sonar.ItemCatalog
    if type(catalog) ~= 'table' or type(catalog.items) ~= 'table' or #catalog.items ~= 21 then
        errors[#errors + 1] = 'Sonar.ItemCatalog must contain exactly 21 canonical items.'
        return
    end
    local counts = { water = 0, weed = 0, fertilize = 0, treat_pest = 0 }
    for _, item in ipairs(catalog.items) do
        local effect = item.tool or item.consumable
        if effect and counts[effect.action] ~= nil then
            counts[effect.action] = counts[effect.action] + 1
            local path = ('Sonar.ItemCatalog.%s'):format(item.id)
            if not catalog.tiers[item.tier] then errors[#errors + 1] = path .. '.tier is invalid.' end
            positive(errors, path .. '.price', item.price, false)
            positive(errors, path .. '.leadMinutes', item.leadMinutes, false)
            if item.tool then
                positive(errors, path .. '.tool.uses', effect.uses, false)
                if effect.action == 'weed' then range(errors, path .. '.tool.weedRemoval', effect.weedRemoval, 0.01, 100) end
            else
                range(errors, path .. '.consumable.protectionStrength', effect.protectionStrength, 0, 1)
                positive(errors, path .. '.consumable.protectionHours', effect.protectionHours, false)
                if effect.action == 'fertilize' then
                    positive(errors, path .. '.consumable.amount', effect.amount, false)
                    positive(errors, path .. '.consumable.burnMultiplier', effect.burnMultiplier, true)
                else
                    range(errors, path .. '.consumable.reduction', effect.reduction, 0.01, 100)
                end
            end
            range(errors, path .. '.protectionCycleRatio', effect.protectionCycleRatio, 0, 1)
        end
    end
    for action, count in pairs(counts) do
        if count ~= 3 then errors[#errors + 1] = ('Canonical catalog requires 3 %s tiers.'):format(action) end
    end
end

local function validateInspection(errors)
    local cfg = Config.Inspection
    if type(cfg) ~= 'table' then
        errors[#errors + 1] = 'Config.Inspection must be a table.'
        return
    end
    for _, key in ipairs({ 'HistorySeconds', 'ForecastSeconds', 'SampleSeconds', 'CurveRefreshSeconds',
        'ValueRefreshSeconds', 'MaxEtaSeconds', 'CloseDistance', 'MinimapGapPixels', 'RightInsetPixels' }) do
        positive(errors, ('Config.Inspection.%s'):format(key), cfg[key], key == 'MinimapGapPixels' or key == 'RightInsetPixels')
    end
    range(errors, 'Config.Inspection.HistoryCycleRatio', cfg.HistoryCycleRatio, 0.01, 1)
    range(errors, 'Config.Inspection.DiagnosisCycleRatio', cfg.DiagnosisCycleRatio, 0.01, 1)
    positive(errors, 'Config.Inspection.MaxEtaCycles', cfg.MaxEtaCycles, false)
    range(errors, 'Config.Inspection.MinimapWidthRatio', cfg.MinimapWidthRatio, 0.05, 0.4)
    range(errors, 'Config.Inspection.SevereConditionPercent', cfg.SevereConditionPercent, 1, 100)
    if finite(cfg.CloseDistance) and finite(Config.Security and Config.Security.MaxInteractDistance)
        and cfg.CloseDistance < Config.Security.MaxInteractDistance then
        errors[#errors + 1] = 'Config.Inspection.CloseDistance must be at least Config.Security.MaxInteractDistance.'
    end
end

local function validateSection(errors, name, fn, ...)
    local ok, err = pcall(fn, errors, ...)
    if not ok then
        errors[#errors + 1] = ('%s validation failed: %s'):format(name, tostring(err))
    end
end

local function validateSupplies(errors)
    local cfg = Config.Supplies
    if type(cfg) ~= 'table' then errors[#errors + 1] = 'Config.Supplies must be a table.'; return end
    nonEmptyString(errors, 'Config.Supplies.Ace', cfg.Ace)
    for _, key in ipairs({ 'DraftTtlSeconds','MaxDraftLines','MaxLineQuantity','MonthlyBudget','BootstrapTreasury','ProcurementLimit','DeliveryWorkerSeconds','UsageRecoveryGraceSeconds','SessionTtlSeconds','InteractionDistance' }) do
        positive(errors, 'Config.Supplies.' .. key, cfg[key], false)
    end
    range(errors, 'Config.Supplies.SupplierFeeRate', cfg.SupplierFeeRate, 0, 1)
    for _, tier in ipairs({ 'plus', 'pro' }) do
        local stock = cfg.SupplierStock and cfg.SupplierStock[tier]
        if type(stock) ~= 'table' then errors[#errors + 1] = 'Config.Supplies.SupplierStock.' .. tier .. ' must be a table.'
        else
            positive(errors, 'Config.Supplies.SupplierStock.' .. tier .. '.capacity', stock.capacity, false)
            positive(errors, 'Config.Supplies.SupplierStock.' .. tier .. '.restockAmount', stock.restockAmount, false)
            positive(errors, 'Config.Supplies.SupplierStock.' .. tier .. '.restockSeconds', stock.restockSeconds, false)
            if finite(stock.capacity) and finite(stock.restockAmount) and stock.restockAmount > stock.capacity then
                errors[#errors + 1] = 'Config.Supplies.SupplierStock.' .. tier .. '.restockAmount cannot exceed capacity.'
            end
        end
    end
end

local function validateFields(errors)
    local cfg = Config.Fields
    if type(cfg) ~= 'table' then errors[#errors + 1] = 'Config.Fields must be a table.'; return end
    nonEmptyString(errors, 'Config.Fields.Ace', cfg.Ace)
    for _, key in ipairs({ 'InteractionDistance', 'DetailRefreshSeconds', 'MaxEventsPerDetail',
        'MinimumSlotSpacing', 'PurchaseDraftTtlSeconds', 'BuyerOrderWorkerSeconds' }) do
        positive(errors, 'Config.Fields.' .. key, cfg[key], false)
    end
    local fields, compileErrors = Sonar.Fields.CompileSeeds()
    for _, message in ipairs(compileErrors) do errors[#errors + 1] = 'Field catalogue: ' .. message end
    local ids, coordinates = {}, {}
    for _, field in ipairs(fields) do
        if ids[field.id] then errors[#errors + 1] = 'Duplicate Field id ' .. field.id end
        ids[field.id] = true
        for _, slot in ipairs(field.slots) do
            local key = ('%.2f:%.2f:%.2f'):format(slot.x, slot.y, slot.z)
            if coordinates[key] then errors[#errors + 1] = ('Fields %s and %s overlap at %s'):format(coordinates[key], field.id, key) end
            coordinates[key] = field.id
        end
    end
    if Config.Features.CompanyFieldAuthority and not (Config.Features.Fields and Config.Features.Work and Config.Features.CompanyCargo) then
        errors[#errors + 1] = 'CompanyFieldAuthority requires Fields, Work and CompanyCargo.'
    end
    if Config.Features.PublicContracts and not (Config.Features.Fields and Config.Features.Work and Config.Features.CompanyCargo) then
        errors[#errors + 1] = 'PublicContracts requires Fields, Work and CompanyCargo.'
    end
    if Config.Features.BuyerOrders and not (Config.Features.Fields and Config.Features.CompanyCargo) then
        errors[#errors + 1] = 'BuyerOrders requires Fields and CompanyCargo.'
    end
    local templateIds = {}
    for index, template in ipairs(cfg.BuyerOrderTemplates or {}) do
        local path = ('Config.Fields.BuyerOrderTemplates[%d]'):format(index)
        nonEmptyString(errors, path .. '.id', template.id)
        nonEmptyString(errors, path .. '.buyer', template.buyer)
        nonEmptyString(errors, path .. '.product', template.product)
        if templateIds[template.id] then errors[#errors + 1] = path .. '.id must be unique.' end
        templateIds[template.id] = true
        local item = Sonar.ItemCatalog.byId[template.product]
        if not item or item.category ~= 'Produce' then errors[#errors + 1] = path .. '.product must be a harvested product.' end
        for _, key in ipairs({ 'quantity', 'intervalSeconds', 'deadlineSeconds', 'payout' }) do
            positive(errors, path .. '.' .. key, template[key], false)
        end
        if not finite(template.minimumQuality) or template.minimumQuality < 0 or template.minimumQuality > 100 then
            errors[#errors + 1] = path .. '.minimumQuality must be between 0 and 100.'
        end
        local coords = template.destination and template.destination.coords
        if type(coords) ~= 'table' and type(coords) ~= 'vector3' then
            errors[#errors + 1] = path .. '.destination.coords must be configured.'
        end
    end
end

function ConfigValidation.Validate()
    local errors, warnings = {}, {}

    validateSection(errors, 'Framework', validateFramework)
    validateSection(errors, 'Crop', validateCrops)
    validateSection(errors, 'Zone', validateZones, warnings)
    validateSection(errors, 'Minigame', validateMinigames)
    validateSection(errors, 'AdvancedCare', validateAdvancedCare)
    validateSection(errors, 'Inspection', validateInspection)
    validateSection(errors, 'Supplies', validateSupplies)
    validateSection(errors, 'Fields', validateFields)

    nonEmptyString(errors, 'Config.Admin.Ace', Config.Admin and Config.Admin.Ace)
    positive(errors, 'Config.SaveInterval', Config.SaveInterval, false)
    positive(errors, 'Config.Database.BatchChunkSize', Config.Database and Config.Database.BatchChunkSize, false)
    positive(errors, 'Config.Security.TokenBucket.capacity', Config.Security and Config.Security.TokenBucket and Config.Security.TokenBucket.capacity, false)
    positive(errors, 'Config.Security.TokenBucket.refillPerSecond', Config.Security and Config.Security.TokenBucket and Config.Security.TokenBucket.refillPerSecond, false)
    positive(errors, 'Config.Security.SubscriptionBucket.capacity', Config.Security and Config.Security.SubscriptionBucket and Config.Security.SubscriptionBucket.capacity, false)
    positive(errors, 'Config.Security.SubscriptionBucket.refillPerSecond', Config.Security and Config.Security.SubscriptionBucket and Config.Security.SubscriptionBucket.refillPerSecond, false)
    positive(errors, 'Config.Security.MinigameBucket.capacity', Config.Security and Config.Security.MinigameBucket and Config.Security.MinigameBucket.capacity, false)
    positive(errors, 'Config.Security.MinigameBucket.refillPerSecond', Config.Security and Config.Security.MinigameBucket and Config.Security.MinigameBucket.refillPerSecond, false)
    positive(errors, 'Config.Security.RateLimitLogInterval', Config.Security and Config.Security.RateLimitLogInterval, false)
    positive(errors, 'Config.Security.MaxInteractDistance', Config.Security and Config.Security.MaxInteractDistance, false)
    positive(errors, 'Config.Security.MaxSpeedMps', Config.Security and Config.Security.MaxSpeedMps, false)
    positive(errors, 'Config.Security.PositionSampleTtl', Config.Security and Config.Security.PositionSampleTtl, false)
    positive(errors, 'Config.Security.ConnectGracePeriod', Config.Security and Config.Security.ConnectGracePeriod, true)
    positive(errors, 'Config.Sync.CellRadius', Config.Sync and Config.Sync.CellRadius, true)
    positive(errors, 'Config.Sync.TickNear', Config.Sync and Config.Sync.TickNear, false)
    positive(errors, 'Config.Sync.TickFar', Config.Sync and Config.Sync.TickFar, false)
    positive(errors, 'Config.Render.Radius', Config.Render and Config.Render.Radius, false)
    positive(errors, 'Config.Render.TargetDistance', Config.Render and Config.Render.TargetDistance, false)
    positive(errors, 'Config.Render.MaxProps', Config.Render and Config.Render.MaxProps, false)
    positive(errors, 'Config.Render.InteractionCacheMs', Config.Render and Config.Render.InteractionCacheMs, false)
    positive(errors, 'Config.Render.VisualStageCacheMs', Config.Render and Config.Render.VisualStageCacheMs, false)
    positive(errors, 'Config.Render.VisualStageJitterMs', Config.Render and Config.Render.VisualStageJitterMs, true)

    if Config.Render and Config.Security
        and finite(Config.Render.TargetDistance)
        and finite(Config.Security.MaxInteractDistance)
        and Config.Render.TargetDistance >= Config.Security.MaxInteractDistance then
        errors[#errors + 1] = 'Config.Render.TargetDistance must be below Config.Security.MaxInteractDistance.'
    end

    local scoreWeight = Config.Quality and Config.Quality.ScoreWeight
    local careWeight = Config.Quality and Config.Quality.CareWeight
    if not finite(scoreWeight)
        or not finite(careWeight)
        or math.abs((scoreWeight + careWeight) - 1) > 0.001 then
        errors[#errors + 1] = 'Config.Quality ScoreWeight + CareWeight must equal 1.'
    end
    local plantingInfluence = Config.Quality and Config.Quality.PlantingInfluence
    if not finite(plantingInfluence) or plantingInfluence < 0 or plantingInfluence > 1 then
        errors[#errors + 1] = 'Config.Quality.PlantingInfluence must be within 0..1.'
    end
    range(errors, 'Config.Quality.DefectWeight', Config.Quality and Config.Quality.DefectWeight, 0, 1)

    if type(Config.Security and Config.Security.AllowedRoutingBuckets) ~= 'table'
        or #Config.Security.AllowedRoutingBuckets == 0 then
        errors[#errors + 1] = 'Config.Security.AllowedRoutingBuckets must contain at least one bucket.'
    else
        local buckets = {}
        for index, bucket in ipairs(Config.Security.AllowedRoutingBuckets) do
            if not finite(bucket) or bucket < 0 or bucket % 1 ~= 0 then
                errors[#errors + 1] = ('Config.Security.AllowedRoutingBuckets[%d] must be a non-negative integer.')
                    :format(index)
            else
                if buckets[bucket] then
                    errors[#errors + 1] = ('Config.Security.AllowedRoutingBuckets contains duplicate %d.'):format(bucket)
                end
                buckets[bucket] = true
            end
        end
    end

    return errors, warnings
end

Sonar.ConfigValidation = ConfigValidation
