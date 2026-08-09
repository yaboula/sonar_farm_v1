--[[
    sonar_farm - Advanced crop condition trajectories (shared, pure)

    Computes the raw condition path since data.lastCare. No mutation happens
    here: both client prediction and server settlement consume the same result.
    The whole module is inert while Config.Features.AdvancedCare is false.
]]

Sonar = Sonar or {}

local Conditions = {}
local Utils = Sonar.Utils

local GLOBAL_KEYS = {
    nutrients = 'Nutrients',
    weeds = 'Weeds',
    pests = 'Pests',
}

local function definitionFor(recordOrType)
    local cropType = type(recordOrType) == 'table' and recordOrType.crop_type or recordOrType
    return Config.Crops and Config.Crops[cropType]
end

local function advancedConfig()
    return Config.Farming and Config.Farming.AdvancedCare or {}
end

local function belowThresholdHours(startValue, decayPerHour, hours, threshold)
    if hours <= 0 then return 0 end
    if startValue <= threshold then return hours end
    if decayPerHour <= 0 then return 0 end
    local crossing = (startValue - threshold) / decayPerHour
    return crossing >= hours and 0 or hours - math.max(0, crossing)
end

local function criticalFactor(record, fromTime, toTime, pendingPenaltyHours)
    local def = definitionFor(record)
    local window = def and def.criticalWindow
    local multiplier = tonumber(advancedConfig().CriticalStressMultiplier) or 1
    if not window or multiplier <= 1 or toTime <= fromTime then return 1 end

    local plantedAt = tonumber(record.planted_at) or fromTime
    local growthTime = tonumber(record.growth_time) or 0
    if growthTime <= 0 then return 1 end

    -- Critical windows belong to the crop's biological progress, not to wall
    -- clock time. Persisted and pending slowdown therefore shift the window
    -- together with the crop instead of letting stress amplification expire
    -- before a delayed crop actually reaches that stage.
    local persistedPenalty = math.max(0, tonumber(record.data and record.data.growthPenaltyHours) or 0) * 3600
    local pendingPenalty = math.max(0, tonumber(pendingPenaltyHours) or 0) * 3600
    local effectiveFrom = math.max(0, fromTime - plantedAt - persistedPenalty)
    local effectiveTo = math.max(effectiveFrom, toTime - plantedAt - persistedPenalty - pendingPenalty)
    local criticalFrom = growthTime * window.from
    local criticalTo = growthTime * window.to
    local effectiveDistance = effectiveTo - effectiveFrom

    if effectiveDistance <= 0 then
        return effectiveFrom >= criticalFrom and effectiveFrom < criticalTo and multiplier or 1
    end

    local overlap = math.max(0, math.min(effectiveTo, criticalTo) - math.max(effectiveFrom, criticalFrom))
    local fraction = overlap / effectiveDistance
    return 1 + fraction * (multiplier - 1)
end

function Conditions.IsAdvancedCareEnabled()
    return Config.Features and Config.Features.AdvancedCare == true
end

---@param recordOrType table|string
---@param condition string nutrients|weeds|pests
---@return boolean
function Conditions.IsEnabled(recordOrType, condition)
    if not Conditions.IsAdvancedCareEnabled() then return false end
    local globalKey = GLOBAL_KEYS[condition]
    if not globalKey then return condition == 'water' end

    local global = Config.Farming and Config.Farming.ConditionEffects
    if not global or global[globalKey] ~= true then return false end

    local def = definitionFor(recordOrType)
    if not def or type(def[condition]) ~= 'table' then return false end
    local overrides = def and def.conditionEffects
    return not overrides or overrides[condition] ~= false
end

---@param record table
---@param now? number unix seconds
---@return table trajectory
function Conditions.Evaluate(record, now)
    now = now or Sonar.Time.Now()
    local data = record.data or {}
    local def = definitionFor(record) or {}
    local cfg = advancedConfig()
    local lastCare = tonumber(data.lastCare) or tonumber(record.planted_at) or now
    local hours = math.max(0, now - lastCare) / 3600

    local weedsEnabled = Conditions.IsEnabled(record, 'weeds')
    local nutrientsEnabled = Conditions.IsEnabled(record, 'nutrients')
    local pestsEnabled = Conditions.IsEnabled(record, 'pests')

    local weedStart = weedsEnabled and Utils.Clamp(tonumber(data.weedCover) or 0, 0, 100) or 0
    local weedParams = def.weeds or {}
    local weedGrowth = weedsEnabled
        and (tonumber(weedParams.growthPerHour) or 0) * (1 - Utils.Clamp(tonumber(weedParams.resistance) or 0, 0, 1))
        or 0
    local weedCover = weedsEnabled and Utils.Clamp(weedStart + weedGrowth * hours, 0, 100) or nil
    local averageWeeds = weedsEnabled and (weedStart + weedCover) * 0.5 or 0

    local waterStart = Utils.Clamp(tonumber(data.water) or 100, 0, 100)
    local waterParams = def.water or { decayPerHour = 15 }
    local waterDecay = (tonumber(waterParams.decayPerHour) or 0)
        * (1 + averageWeeds / 100 * (tonumber(cfg.WeedWaterCompetition) or 0))
    local water = Utils.Clamp(waterStart - waterDecay * hours, 0, 100)
    local hoursUntilDry = waterDecay > 0 and waterStart / waterDecay or math.huge
    local waterDryHours = math.max(0, hours - hoursUntilDry)
    local waterDeficitHours = belowThresholdHours(
        waterStart,
        waterDecay,
        hours,
        tonumber(cfg.WaterDeficitThreshold) or 35
    )

    local nutrientStart = nutrientsEnabled and Utils.Clamp(tonumber(data.nutrients) or 100, 0, 100) or nil
    local nutrientParams = def.nutrients or {}
    local nutrientDecay = nutrientsEnabled
        and (tonumber(nutrientParams.decayPerHour) or 0)
            * (1 + averageWeeds / 100 * (tonumber(cfg.WeedNutrientCompetition) or 0))
        or 0
    local nutrients = nutrientsEnabled and Utils.Clamp(nutrientStart - nutrientDecay * hours, 0, 100) or nil
    local nutrientDeficitHours = nutrientsEnabled and belowThresholdHours(
        nutrientStart,
        nutrientDecay,
        hours,
        tonumber(nutrientParams.optimalMin) or 40
    ) or 0

    local pestStart = pestsEnabled and Utils.Clamp(tonumber(data.pestPressure) or 0, 0, 100) or 0
    local pestParams = def.pests or {}
    local onsetAt = (tonumber(record.planted_at) or lastCare) + (tonumber(pestParams.onsetHours) or 0) * 3600
    local activeSeconds = pestsEnabled
        and math.max(0, now - math.max(lastCare, onsetAt))
        or 0
    local pestHours = activeSeconds / 3600
    local pestGrowth = (tonumber(cfg.PestGrowthPerHour) or 0)
        * Utils.Clamp(tonumber(pestParams.susceptibility) or 0, 0, 1)
        * (1 + averageWeeds / 100 * (tonumber(cfg.PestWeedAcceleration) or 0))
    local pestPressure = pestsEnabled and Utils.Clamp(pestStart + pestGrowth * pestHours, 0, 100) or nil
    local averagePests = pestsEnabled and (pestStart + pestPressure) * 0.5 or 0

    local penaltyRates = cfg.GrowthPenaltyPerDeficitHour or {}
    local waterPenaltyRate = math.max(0, tonumber(penaltyRates.water) or 0)
    local nutrientPenaltyRate = math.max(0, tonumber(penaltyRates.nutrients) or 0)
    local rateScale = math.max(1, waterPenaltyRate + nutrientPenaltyRate)
    local rawGrowthPenalty = (waterDeficitHours * waterPenaltyRate
        + nutrientDeficitHours * nutrientPenaltyRate) / rateScale
    -- A crop may stop growing under extreme neglect, but its biological clock
    -- must never run backwards. Config validation also enforces a combined
    -- rate <= 1; runtime normalization also protects hot-mutated config.
    local growthPenalty = Utils.Clamp(rawGrowthPenalty, 0, hours)
    local stressFactor = criticalFactor(record, lastCare, now, growthPenalty)
    local weightedWaterDeficit = waterDeficitHours * stressFactor
    local weightedNutrientDeficit = nutrientDeficitHours * stressFactor
    local pestDamageDelta = pestsEnabled
        and pestHours * averagePests / 100 * (tonumber(cfg.PestDamagePerHour) or 0) * stressFactor
        or 0

    local stressRates = cfg.StressPerDeficitHour or {}

    return {
        hours = hours,
        lastCare = lastCare,
        water = water,
        waterDeficitHours = waterDeficitHours,
        waterDryHours = waterDryHours,
        nutrients = nutrients,
        nutrientDeficitHours = nutrientDeficitHours,
        weedCover = weedCover,
        pestPressure = pestPressure,
        growthPenaltyHoursDelta = growthPenalty,
        waterStressDelta = weightedWaterDeficit * (tonumber(stressRates.water) or 0),
        nutrientStressDelta = weightedNutrientDeficit * (tonumber(stressRates.nutrients) or 0),
        pestDamageDelta = pestDamageDelta,
        criticalFactor = stressFactor,
        enabled = {
            nutrients = nutrientsEnabled,
            weeds = weedsEnabled,
            pests = pestsEnabled,
        },
    }
end

---@param condition? table
---@return string defect
function Conditions.DominantDefect(condition)
    condition = condition or {}
    local risks = {
        { key = 'water_stress', value = tonumber(condition.waterStressAccumulated) or 0 },
        {
            key = 'nutrient_burn',
            value = (tonumber(condition.nutrientStressAccumulated) or 0)
                + (tonumber(condition.overfertilizeExcess) or 0),
        },
        { key = 'pest_damage', value = tonumber(condition.pestDamageAccumulated) or 0 },
    }
    local winner, highest = 'none', 0
    for _, entry in ipairs(risks) do
        if entry.value > highest then winner, highest = entry.key, entry.value end
    end
    return winner
end

Sonar.Conditions = Conditions
