--[[
    sonar_farm - Plant physiology mutators (server)
    The evaluation itself is shared (see shared/physiology.lua) because the client
    predicts it for rendering. What lives here is everything that *writes*: only
    the server may change a crop's condition.
]]

local Utils = Sonar.Utils

--- Evaluate and commit the condition into hot state. Call this before any action
--- that depends on current water/health/state.
---@param record table
---@param now? number
---@return table condition
function Physiology.Apply(record, now)
    now = now or Sonar.Time.Now()
    local condition = Physiology.Evaluate(record, now)

    local dataPatch = {
        water = condition.water,
        health = condition.health,
        spoilage = condition.spoilage,
        -- Advance the care clock so decay is not applied twice.
        lastCare = now,
        simulationVersion = Sonar.CropClock.Version(record),
    }
    if Sonar.CropClock.IsV2(record) then
        dataPatch.growthAdjustmentRatio = condition.growthAdjustmentRatio
        if condition.maturedAt then dataPatch.maturedAt = condition.maturedAt end
    elseif Sonar.Conditions.IsAdvancedCareEnabled() then
        dataPatch.growthPenaltyHours = condition.growthPenaltyHours
    end
    if Sonar.Conditions.IsAdvancedCareEnabled() or Sonar.CropClock.IsV2(record) then
        dataPatch.waterStressAccumulated = condition.waterStressAccumulated
        dataPatch.waterProtectionStrength = condition.waterProtectionStrength
        dataPatch.waterProtectionUntil = condition.waterProtectionUntil
        dataPatch.waterProtectionTier = condition.waterProtectionTier
        dataPatch.waterProtectionItem = condition.waterProtectionItem
        if Sonar.Conditions.IsEnabled(record, 'nutrients') then
            dataPatch.nutrients = condition.nutrients
            dataPatch.nutrientStressAccumulated = condition.nutrientStressAccumulated
            dataPatch.overfertilizeExcess = condition.overfertilizeExcess
            dataPatch.nutrientProtectionStrength = condition.nutrientProtectionStrength
            dataPatch.nutrientProtectionUntil = condition.nutrientProtectionUntil
            dataPatch.nutrientProtectionTier = condition.nutrientProtectionTier
            dataPatch.nutrientProtectionItem = condition.nutrientProtectionItem
        end
        if Sonar.Conditions.IsEnabled(record, 'weeds') then
            dataPatch.weedCover = condition.weedCover
            dataPatch.weedProtectionStrength = condition.weedProtectionStrength
            dataPatch.weedProtectionUntil = condition.weedProtectionUntil
            dataPatch.weedProtectionTier = condition.weedProtectionTier
            dataPatch.weedProtectionItem = condition.weedProtectionItem
        end
        if Sonar.Conditions.IsEnabled(record, 'pests') then
            dataPatch.pestPressure = condition.pestPressure
            dataPatch.pestDamageAccumulated = condition.pestDamageAccumulated
            dataPatch.pestProtectionStrength = condition.pestProtectionStrength
            dataPatch.pestProtectionUntil = condition.pestProtectionUntil
            dataPatch.pestProtectionTier = condition.pestProtectionTier
            dataPatch.pestProtectionItem = condition.pestProtectionItem
        end
    end

    State.Update(record.id, { state = condition.state, data = dataPatch })

    return condition
end

---@param record table
---@param amount number
---@param burnMultiplier? number
---@return number nutrients
---@return number excess
function Physiology.Fertilize(record, effect, item)
    if type(effect) == 'number' then
        effect = { amount = effect, burnMultiplier = tonumber(item) or 1, protectionHours = 0, protectionStrength = 0 }
        item = nil
    end
    effect = effect or {}
    item = item or { tier = record.data and record.data.nutrientProtectionTier, id = record.data and record.data.nutrientProtectionItem }
    local data = record.data or {}
    local def = Config.Crops and Config.Crops[record.crop_type] or {}
    local params = def.nutrients or {}
    local ceiling = tonumber(params.overfertilizeCeiling) or 100
    local optimalMax = tonumber(params.optimalMax) or ceiling
    local previous = Utils.Clamp(tonumber(data.nutrients) or 100, 0, ceiling)
    local nutrients = Utils.Clamp(previous + (effect.amount or 0), 0, ceiling)
    local newlyExcessive = math.max(0, nutrients - optimalMax) - math.max(0, previous - optimalMax)
    local excess = math.max(0, newlyExcessive) * (effect.burnMultiplier or 1)
    local accumulated = Utils.Clamp((tonumber(data.overfertilizeExcess) or 0) + excess, 0, 100)
    local now = Sonar.Time.Now()
    local oldUntil = tonumber(data.nutrientProtectionUntil) or 0
    local oldStrength = Utils.Clamp(tonumber(data.nutrientProtectionStrength) or 0, 0, 1)
    local oldScore = oldStrength * math.max(0, oldUntil - now)
    local newUntil = now + Sonar.CropClock.ProtectionSeconds(record, effect)
    local newStrength = Utils.Clamp(tonumber(effect.protectionStrength) or 0, 0, 1)
    local keepNew = newStrength * math.max(0, newUntil - now) >= oldScore
    State.Update(record.id, { data = {
        nutrients = Utils.Round(nutrients, 1),
        overfertilizeExcess = Utils.Round(accumulated, 2),
        nutrientProtectionStrength = keepNew and newStrength or oldStrength,
        nutrientProtectionUntil = keepNew and newUntil or oldUntil,
        nutrientProtectionTier = keepNew and item.tier or data.nutrientProtectionTier,
        nutrientProtectionItem = keepNew and item.id or data.nutrientProtectionItem,
        lastCare = now,
    } })
    return nutrients, accumulated
end

---@param record table
---@param effect table|number
---@param item? table
---@return number weedCover
function Physiology.Weed(record, effect, item)
    local data = record.data or {}
    local removal = 55
    local protectionStrength = 0
    if type(effect) == 'table' then
        removal = tonumber(effect.weedRemoval) or 55
        protectionStrength = tonumber(effect.protectionStrength) or 0
    elseif type(effect) == 'number' then
        removal = effect
    end
    item = item or { tier = data and data.weedProtectionTier, id = data and data.weedProtectionItem }
    local weedCover = Utils.Clamp((tonumber(data.weedCover) or 0) - removal, 0, 100)

    local now = Sonar.Time.Now()
    local oldUntil = tonumber(data.weedProtectionUntil) or 0
    local oldStrength = Utils.Clamp(tonumber(data.weedProtectionStrength) or 0, 0, 1)
    local oldScore = oldStrength * math.max(0, oldUntil - now)
    local newUntil = now + Sonar.CropClock.ProtectionSeconds(record,
        type(effect) == 'table' and effect or {})
    local newStrength = Utils.Clamp(protectionStrength, 0, 1)
    local keepNew = newStrength * math.max(0, newUntil - now) >= oldScore

    State.Update(record.id, { data = {
        weedCover = Utils.Round(weedCover, 1),
        weedProtectionStrength = keepNew and newStrength or oldStrength,
        weedProtectionUntil = keepNew and newUntil or oldUntil,
        weedProtectionTier = keepNew and item and item.tier or data.weedProtectionTier,
        weedProtectionItem = keepNew and item and item.id or data.weedProtectionItem,
        lastCare = now,
    } })
    return weedCover
end

---@param record table
---@param amount number
---@return number pestPressure
function Physiology.TreatPests(record, effect, item)
    if type(effect) == 'number' then effect = { reduction = effect, protectionHours = 0, protectionStrength = 0 } end
    effect = effect or {}
    item = item or { tier = record.data and record.data.pestProtectionTier, id = record.data and record.data.pestProtectionItem }
    local data = record.data or {}
    local pressure = Utils.Clamp((tonumber(data.pestPressure) or 0) - (effect.reduction or 0), 0, 100)
    local now = Sonar.Time.Now()
    local oldUntil = tonumber(data.pestProtectionUntil) or 0
    local oldStrength = Utils.Clamp(tonumber(data.pestProtectionStrength) or 0, 0, 1)
    local oldScore = oldStrength * math.max(0, oldUntil - now)
    local newUntil = now + Sonar.CropClock.ProtectionSeconds(record, effect)
    local newStrength = Utils.Clamp(tonumber(effect.protectionStrength) or 0, 0, 1)
    local keepNew = newStrength * math.max(0, newUntil - now) >= oldScore
    State.Update(record.id, { data = {
        pestPressure = Utils.Round(pressure, 1),
        pestProtectionStrength = keepNew and newStrength or oldStrength,
        pestProtectionUntil = keepNew and newUntil or oldUntil,
        pestProtectionTier = keepNew and item.tier or data.pestProtectionTier,
        pestProtectionItem = keepNew and item.id or data.pestProtectionItem,
        lastCare = now,
    } })
    return pressure
end

--- Water a crop: restore water and record the care for quality purposes.
---@param record table
---@param effect? table|number
---@param item? table
---@param now? number
function Physiology.Water(record, effect, item, now)
    now = now or Sonar.Time.Now()
    local data = record.data or {}
    local amount = 100
    local protectionStrength = 0
    if type(effect) == 'table' then
        amount = tonumber(effect.amount) or 100
        protectionStrength = tonumber(effect.protectionStrength) or 0
    elseif type(effect) == 'number' then
        amount = effect
    end
    item = item or { tier = data and data.waterProtectionTier, id = data and data.waterProtectionItem }
    local newWater = Utils.Clamp((tonumber(data.water) or 0) + amount, 0, 100)

    local oldUntil = tonumber(data.waterProtectionUntil) or 0
    local oldStrength = Utils.Clamp(tonumber(data.waterProtectionStrength) or 0, 0, 1)
    local oldScore = oldStrength * math.max(0, oldUntil - now)
    local newUntil = now + Sonar.CropClock.ProtectionSeconds(record,
        type(effect) == 'table' and effect or {})
    local newStrength = Utils.Clamp(protectionStrength, 0, 1)
    local keepNew = newStrength * math.max(0, newUntil - now) >= oldScore

    State.Update(record.id, {
        data = {
            water = newWater,
            waterProtectionStrength = keepNew and newStrength or oldStrength,
            waterProtectionUntil = keepNew and newUntil or oldUntil,
            waterProtectionTier = keepNew and item and item.tier or data.waterProtectionTier,
            waterProtectionItem = keepNew and item and item.id or data.waterProtectionItem,
            lastCare = now,
            careCount = (tonumber(data.careCount) or 0) + 1,
        },
    })
end
