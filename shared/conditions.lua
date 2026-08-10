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

-- Split a lazy interval at protection expiry. This keeps decay/growth exact
-- even when one evaluation spans both protected and unprotected time.
local function protectionSegments(fromTime, toTime, untilTime, strength)
    local result = {}
    if toTime <= fromTime then return result end
    untilTime = tonumber(untilTime) or 0
    strength = Utils.Clamp(tonumber(strength) or 0, 0, 1)
    local protectedEnd = math.min(toTime, math.max(fromTime, untilTime))
    if protectedEnd > fromTime then
        result[#result + 1] = { hours = (protectedEnd - fromTime) / 3600, multiplier = 1 - strength }
    end
    if toTime > protectedEnd then
        result[#result + 1] = { hours = (toTime - protectedEnd) / 3600, multiplier = 1 }
    end
    return result
end

local function evaluateDecay(startValue, rate, segments, threshold)
    local value, below = startValue, 0
    for _, segment in ipairs(segments) do
        local segmentRate = rate * segment.multiplier
        below = below + belowThresholdHours(value, segmentRate, segment.hours, threshold)
        value = Utils.Clamp(value - segmentRate * segment.hours, 0, 100)
    end
    return value, below
end

local function evaluateGrowth(startValue, rate, segments)
    local value, exposure = startValue, 0
    for _, segment in ipairs(segments) do
        local segmentRate = rate * segment.multiplier
        local nextValue = Utils.Clamp(value + segmentRate * segment.hours, 0, 100)
        exposure = exposure + ((value + nextValue) * 0.5 / 100) * segment.hours
        value = nextValue
    end
    return value, exposure
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
    local elapsedFrom = math.max(0, fromTime - plantedAt)
    local persistedAdjustment = Utils.Clamp(
        tonumber(record.data and record.data.growthPenaltyHours) or 0,
        -(elapsedFrom / 3600) * 0.15,
        elapsedFrom / 3600
    ) * 3600
    local pendingAdjustment = tonumber(pendingPenaltyHours) or 0
    local effectiveFrom = math.max(0, fromTime - plantedAt - persistedAdjustment)
    local effectiveTo = math.max(effectiveFrom, toTime - plantedAt - persistedAdjustment - pendingAdjustment * 3600)
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

-- ---------------------------------------------------------------------------
-- V2 cycle-normalized trajectories
-- ---------------------------------------------------------------------------

local BAND = { green = 0, watch = 1, critical = 2 }

local function uniqueSorted(values)
    table.sort(values)
    local result = {}
    for _, value in ipairs(values) do
        if value >= 0 and (not result[#result] or math.abs(value - result[#result]) > 0.0000001) then
            result[#result + 1] = value
        end
    end
    return result
end

local function valueAt(path, offset)
    if not path or #path == 0 then return 0 end
    for _, segment in ipairs(path) do
        if offset <= segment.finish + 0.0000001 then
            local length = segment.finish - segment.start
            if length <= 0 then return segment.to end
            local ratio = Utils.Clamp((offset - segment.start) / length, 0, 1)
            return segment.from + (segment.to - segment.from) * ratio
        end
    end
    return path[#path].to
end

local function pathBoundaries(path, values)
    for _, segment in ipairs(path or {}) do
        values[#values + 1] = segment.start
        values[#values + 1] = segment.finish
    end
end

local function addCrossings(path, threshold, values)
    for _, segment in ipairs(path or {}) do
        local low, high = math.min(segment.from, segment.to), math.max(segment.from, segment.to)
        if threshold > low and threshold < high and math.abs(segment.to - segment.from) > 0.0000001 then
            local ratio = (threshold - segment.from) / (segment.to - segment.from)
            values[#values + 1] = segment.start + (segment.finish - segment.start) * ratio
        end
    end
end

local function linearPath(record, fromTime, toTime, startValue, baseRate, direction, options)
    options = options or {}
    local total = Sonar.CropClock.Between(record, fromTime, toTime)
    local growthSeconds = Sonar.CropClock.GrowthSeconds(record)
    local boundaries = { 0, total }
    local untilTime = tonumber(options.protectionUntil) or 0
    if untilTime > fromTime and untilTime < toTime then
        boundaries[#boundaries + 1] = (untilTime - fromTime) / growthSeconds
    end
    if options.onsetRatio then
        local plantedAt = tonumber(record.planted_at) or fromTime
        local baseRatio = Sonar.CropClock.Between(record, plantedAt, fromTime)
        local onsetOffset = options.onsetRatio - baseRatio
        if onsetOffset > 0 and onsetOffset < total then boundaries[#boundaries + 1] = onsetOffset end
    end
    pathBoundaries(options.weedPath, boundaries)
    boundaries = uniqueSorted(boundaries)

    local path = {}
    local value = Utils.Clamp(tonumber(startValue) or 0, 0, 100)
    local strength = Utils.Clamp(tonumber(options.protectionStrength) or 0, 0, 1)
    local plantedAt = tonumber(record.planted_at) or fromTime
    local baseRatio = Sonar.CropClock.Between(record, plantedAt, fromTime)
    for index = 1, #boundaries - 1 do
        local left, right = boundaries[index], boundaries[index + 1]
        if right > left then
            local middle = (left + right) * 0.5
            local active = not options.onsetRatio or baseRatio + middle >= options.onsetRatio
            local protectionMultiplier = (fromTime + middle * growthSeconds) < untilTime and (1 - strength) or 1
            local weedMultiplier = 1
            if options.weedPath then
                local weedAverage = (valueAt(options.weedPath, left) + valueAt(options.weedPath, right)) * 0.5
                weedMultiplier = 1 + weedAverage / 100 * (tonumber(options.weedCompetition) or 0)
            end
            local rate = active and math.max(0, tonumber(baseRate) or 0)
                * protectionMultiplier * weedMultiplier or 0
            local signedRate = direction * rate
            local raw = value + signedRate * (right - left)
            local target = Utils.Clamp(raw, 0, 100)
            local cap = signedRate > 0 and 100 or 0
            if rate > 0 and raw ~= target then
                local crossing = left + math.abs(cap - value) / rate
                if crossing > left then
                    path[#path + 1] = { start = left, finish = crossing, from = value, to = cap }
                end
                if right > crossing then
                    path[#path + 1] = { start = crossing, finish = right, from = cap, to = cap }
                end
                value = cap
            else
                path[#path + 1] = { start = left, finish = right, from = value, to = target }
                value = target
            end
        end
    end
    if #path == 0 then path[1] = { start = 0, finish = total, from = value, to = value } end
    return path, value
end

local function waterBand(value, cfg)
    if value >= cfg.Water.green then return BAND.green end
    if value >= cfg.Water.critical then return BAND.watch end
    return BAND.critical
end

local function nutrientBand(value, params, cfg)
    local minimum = tonumber(params.optimalMin) or 40
    local maximum = tonumber(params.optimalMax) or 80
    if value >= minimum and value <= maximum then return BAND.green end
    local margin = tonumber(cfg.NutrientWatchMargin) or 20
    if value >= minimum - margin and value <= maximum + margin then return BAND.watch end
    return BAND.critical
end

local function pressureBand(value, cfg)
    if value <= cfg.Pressure.green then return BAND.green end
    if value <= cfg.Pressure.critical then return BAND.watch end
    return BAND.critical
end

local function cycleCriticalFactor(record, normalizedProgress)
    local def = definitionFor(record) or {}
    local window = def.criticalWindow
    if not window then return 1 end
    if normalizedProgress >= (tonumber(window.from) or 0)
        and normalizedProgress < (tonumber(window.to) or 1) then
        return tonumber(advancedConfig().CriticalStressMultiplier) or 1
    end
    return 1
end

local function evaluateCycle(record, now)
    local data = record.data or {}
    local def = definitionFor(record) or {}
    local cycleDef = def.cycle or {}
    local cfg = advancedConfig().Cycle or {}
    local lastCare = math.max(tonumber(record.planted_at) or now,
        tonumber(data.lastCare) or tonumber(record.planted_at) or now)
    local total = Sonar.CropClock.Between(record, lastCare, now)
    local nutrientsEnabled = Conditions.IsEnabled(record, 'nutrients')
    local weedsEnabled = Conditions.IsEnabled(record, 'weeds')
    local pestsEnabled = Conditions.IsEnabled(record, 'pests')
    local nutrientParams = def.nutrients or {}
    local nutrientDefault = ((tonumber(nutrientParams.optimalMin) or 40)
        + (tonumber(nutrientParams.optimalMax) or 80)) * 0.5

    local weedStart = weedsEnabled and Utils.Clamp(tonumber(data.weedCover) or 0, 0, 100) or 0
    local weedPath, weedCover = linearPath(record, lastCare, now, weedStart,
        weedsEnabled and cycleDef.weedGrowth or 0, 1, {
            protectionUntil = data.weedProtectionUntil,
            protectionStrength = data.weedProtectionStrength,
        })

    local waterStart = Utils.Clamp(tonumber(data.water) or 100, 0, 100)
    local waterPath, water = linearPath(record, lastCare, now, waterStart,
        cycleDef.waterLoss or 0, -1, {
            protectionUntil = data.waterProtectionUntil,
            protectionStrength = data.waterProtectionStrength,
            weedPath = weedsEnabled and weedPath or nil,
            weedCompetition = cfg.WeedWaterCompetition,
        })

    local nutrientStart = nutrientsEnabled
        and Utils.Clamp(tonumber(data.nutrients) or nutrientDefault, 0, 100) or 0
    local nutrientPath, nutrients = linearPath(record, lastCare, now, nutrientStart,
        nutrientsEnabled and cycleDef.nutrientLoss or 0, -1, {
            protectionUntil = data.nutrientProtectionUntil,
            protectionStrength = data.nutrientProtectionStrength,
            weedPath = weedsEnabled and weedPath or nil,
            weedCompetition = cfg.WeedNutrientCompetition,
        })

    local pestStart = pestsEnabled and Utils.Clamp(tonumber(data.pestPressure) or 0, 0, 100) or 0
    local pestPath, pestPressure = linearPath(record, lastCare, now, pestStart,
        pestsEnabled and cycleDef.pestGrowth or 0, 1, {
            protectionUntil = data.pestProtectionUntil,
            protectionStrength = data.pestProtectionStrength,
            weedPath = weedsEnabled and weedPath or nil,
            weedCompetition = cfg.PestWeedAcceleration,
            onsetRatio = tonumber(cycleDef.pestOnset) or 1,
        })

    local boundaries = { 0, total }
    for _, path in ipairs({ waterPath, nutrientPath, weedPath, pestPath }) do pathBoundaries(path, boundaries) end
    addCrossings(waterPath, cfg.Water.green or 60, boundaries)
    addCrossings(waterPath, cfg.Water.critical or 35, boundaries)
    addCrossings(waterPath, 0, boundaries)
    if nutrientsEnabled then
        local minimum = tonumber(nutrientParams.optimalMin) or 40
        local maximum = tonumber(nutrientParams.optimalMax) or 80
        local margin = tonumber(cfg.NutrientWatchMargin) or 20
        for _, threshold in ipairs({ minimum - margin, minimum, maximum, maximum + margin }) do
            addCrossings(nutrientPath, threshold, boundaries)
        end
    end
    for _, path in ipairs({ weedPath, pestPath }) do
        addCrossings(path, cfg.Pressure.green or 20, boundaries)
        addCrossings(path, cfg.Pressure.critical or 50, boundaries)
    end
    boundaries = uniqueSorted(boundaries)

    local greenCycle, watchCycle, criticalCycle = 0, 0, 0
    local waterStressExposure, nutrientStressExposure = 0, 0
    local waterDryCycle, nutrientCriticalCycle, pestDamageDelta = 0, 0, 0
    local persistedAdjustment = tonumber(data.growthAdjustmentRatio) or 0
    local pendingAdjustment = 0
    local plantedAt = tonumber(record.planted_at) or lastCare
    local baseCycle = Sonar.CropClock.Between(record, plantedAt, lastCare)
    local watchWeight = tonumber(cfg.WatchStressMultiplier) or 0.35

    for index = 1, #boundaries - 1 do
        local left, right = boundaries[index], boundaries[index + 1]
        local length = right - left
        if length > 0 then
            local middle = (left + right) * 0.5
            local waterValue = valueAt(waterPath, middle)
            local nutrientValue = valueAt(nutrientPath, middle)
            local weedValue = valueAt(weedPath, middle)
            local pestValue = valueAt(pestPath, middle)
            local wb = waterBand(waterValue, cfg)
            local nb = nutrientsEnabled and nutrientBand(nutrientValue, nutrientParams, cfg) or BAND.green
            local web = weedsEnabled and pressureBand(weedValue, cfg) or BAND.green
            local pb = pestsEnabled and pressureBand(pestValue, cfg) or BAND.green
            local overall = math.max(wb, nb, web, pb)
            if overall == BAND.green then greenCycle = greenCycle + length
            elseif overall == BAND.watch then watchCycle = watchCycle + length
            else criticalCycle = criticalCycle + length end

            local adjustmentRate = overall == BAND.green and -(tonumber(cfg.GreenGrowthBonus) or 0.20)
                or overall == BAND.watch and (tonumber(cfg.WatchGrowthPenalty) or 0.10)
                or (tonumber(cfg.CriticalGrowthPenalty) or 0.55)
            local effectiveAtLeft = math.max(0,
                baseCycle + left - persistedAdjustment - pendingAdjustment)
            local effectiveRate = 1 - adjustmentRate
            local subBoundaries = { left, right }
            local window = def.criticalWindow
            if window and effectiveRate > 0 then
                for _, threshold in ipairs({ tonumber(window.from), tonumber(window.to) }) do
                    if threshold then
                        local crossing = left + (threshold - effectiveAtLeft) / effectiveRate
                        if crossing > left and crossing < right then subBoundaries[#subBoundaries + 1] = crossing end
                    end
                end
            end
            subBoundaries = uniqueSorted(subBoundaries)
            for subIndex = 1, #subBoundaries - 1 do
                local subLeft, subRight = subBoundaries[subIndex], subBoundaries[subIndex + 1]
                local subLength = subRight - subLeft
                local subMiddle = (subLeft + subRight) * 0.5
                local normalizedProgress = effectiveAtLeft + (subMiddle - left) * effectiveRate
                local factor = cycleCriticalFactor(record, normalizedProgress)
                waterStressExposure = waterStressExposure
                    + subLength * (wb == BAND.critical and 1 or wb == BAND.watch and watchWeight or 0) * factor
                nutrientStressExposure = nutrientStressExposure
                    + subLength * (nb == BAND.critical and 1 or nb == BAND.watch and watchWeight or 0) * factor
                if waterValue <= 0.0001 then waterDryCycle = waterDryCycle + subLength end
                if nutrientsEnabled and nb == BAND.critical
                    and nutrientValue < (tonumber(nutrientParams.optimalMin) or 40) then
                    nutrientCriticalCycle = nutrientCriticalCycle + subLength
                end
                if pestsEnabled then
                    local leftPressure = valueAt(pestPath, subLeft)
                    local rightPressure = valueAt(pestPath, subRight)
                    local susceptibility = Utils.Clamp(tonumber(def.pests
                        and def.pests.susceptibility) or 1, 0, 1)
                    pestDamageDelta = pestDamageDelta
                        + ((leftPressure + rightPressure) * 0.5 / 100) * subLength
                            * (tonumber(cfg.PestDamagePerCycle) or 0) * susceptibility * factor
                end
            end
            pendingAdjustment = pendingAdjustment + adjustmentRate * length
        end
    end

    return {
        cycleDelta = total,
        lastCare = lastCare,
        water = water,
        waterDryCycle = waterDryCycle,
        nutrients = nutrientsEnabled and nutrients or nil,
        nutrientCriticalCycle = nutrientCriticalCycle,
        weedCover = weedsEnabled and weedCover or nil,
        pestPressure = pestsEnabled and pestPressure or nil,
        growthAdjustmentRatioDelta = Utils.Clamp(pendingAdjustment,
            -total * (tonumber(cfg.GreenGrowthBonus) or 0.20), total),
        waterStressDelta = waterStressExposure * (tonumber(cfg.StressPerCycle and cfg.StressPerCycle.water) or 0),
        nutrientStressDelta = nutrientStressExposure * (tonumber(cfg.StressPerCycle and cfg.StressPerCycle.nutrients) or 0),
        pestDamageDelta = pestDamageDelta,
        bandExposure = { green = greenCycle, watch = watchCycle, critical = criticalCycle },
        waterProtectionStrength = Utils.Clamp(tonumber(data.waterProtectionStrength) or 0, 0, 1),
        waterProtectionUntil = tonumber(data.waterProtectionUntil) or 0,
        waterProtectionTier = data.waterProtectionTier,
        waterProtectionItem = data.waterProtectionItem,
        nutrientProtectionStrength = Utils.Clamp(tonumber(data.nutrientProtectionStrength) or 0, 0, 1),
        nutrientProtectionUntil = tonumber(data.nutrientProtectionUntil) or 0,
        nutrientProtectionTier = data.nutrientProtectionTier,
        nutrientProtectionItem = data.nutrientProtectionItem,
        weedProtectionStrength = Utils.Clamp(tonumber(data.weedProtectionStrength) or 0, 0, 1),
        weedProtectionUntil = tonumber(data.weedProtectionUntil) or 0,
        weedProtectionTier = data.weedProtectionTier,
        weedProtectionItem = data.weedProtectionItem,
        pestProtectionStrength = Utils.Clamp(tonumber(data.pestProtectionStrength) or 0, 0, 1),
        pestProtectionUntil = tonumber(data.pestProtectionUntil) or 0,
        pestProtectionTier = data.pestProtectionTier,
        pestProtectionItem = data.pestProtectionItem,
        enabled = { nutrients = nutrientsEnabled, weeds = weedsEnabled, pests = pestsEnabled },
    }
end

---@param record table
---@param now? number unix seconds
---@return table trajectory
local function evaluateLegacy(record, now)
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
    local weedProtectionStrength = Utils.Clamp(tonumber(data.weedProtectionStrength) or 0, 0, 1)
    local weedProtectionUntil = tonumber(data.weedProtectionUntil) or 0
    local weedSegments = weedsEnabled and protectionSegments(lastCare, now, weedProtectionUntil, weedProtectionStrength) or {}
    local weedCover, weedExposureHours = nil, 0
    if weedsEnabled then
        weedCover, weedExposureHours = evaluateGrowth(weedStart, weedGrowth, weedSegments)
    end
    local averageWeeds = weedsEnabled and (weedStart + (weedCover or weedStart)) * 0.5 or 0

    local waterStart = Utils.Clamp(tonumber(data.water) or 100, 0, 100)
    local waterParams = def.water or { decayPerHour = 15 }
    local waterDecay = (tonumber(waterParams.decayPerHour) or 0)
        * (1 + averageWeeds / 100 * (tonumber(cfg.WeedWaterCompetition) or 0))
    local waterProtectionStrength = Utils.Clamp(tonumber(data.waterProtectionStrength) or 0, 0, 1)
    local waterProtectionUntil = tonumber(data.waterProtectionUntil) or 0
    local waterSegments = protectionSegments(lastCare, now, waterProtectionUntil, waterProtectionStrength)
    local water, waterDeficitHours = evaluateDecay(
        waterStart,
        waterDecay,
        waterSegments,
        tonumber(cfg.WaterDeficitThreshold) or 35
    )
    local _, waterDryHours = evaluateDecay(waterStart, waterDecay, waterSegments, 0)

    local nutrientStart = nutrientsEnabled and Utils.Clamp(tonumber(data.nutrients) or 100, 0, 100) or nil
    local nutrientParams = def.nutrients or {}
    local nutrientDecay = nutrientsEnabled
        and (tonumber(nutrientParams.decayPerHour) or 0)
            * (1 + averageWeeds / 100 * (tonumber(cfg.WeedNutrientCompetition) or 0))
        or 0
    local nutrientProtectionStrength = Utils.Clamp(tonumber(data.nutrientProtectionStrength) or 0, 0, 1)
    local nutrientProtectionUntil = tonumber(data.nutrientProtectionUntil) or 0
    local nutrientSegments = protectionSegments(lastCare, now, nutrientProtectionUntil, nutrientProtectionStrength)
    local nutrients, nutrientDeficitHours
    if nutrientsEnabled then
        nutrients, nutrientDeficitHours = evaluateDecay(
            nutrientStart,
            nutrientDecay,
            nutrientSegments,
            tonumber(nutrientParams.optimalMin) or 40
        )
    end
    nutrientDeficitHours = nutrientDeficitHours or 0

    local pestStart = pestsEnabled and Utils.Clamp(tonumber(data.pestPressure) or 0, 0, 100) or 0
    local pestParams = def.pests or {}
    local onsetAt = (tonumber(record.planted_at) or lastCare) + (tonumber(pestParams.onsetHours) or 0) * 3600
    local pestGrowth = (tonumber(cfg.PestGrowthPerHour) or 0)
        * Utils.Clamp(tonumber(pestParams.susceptibility) or 0, 0, 1)
        * (1 + averageWeeds / 100 * (tonumber(cfg.PestWeedAcceleration) or 0))
    local pestProtectionStrength = Utils.Clamp(tonumber(data.pestProtectionStrength) or 0, 0, 1)
    local pestProtectionUntil = tonumber(data.pestProtectionUntil) or 0
    local pestFrom = math.max(lastCare, onsetAt)
    local pestSegments = pestsEnabled and protectionSegments(pestFrom, now, pestProtectionUntil, pestProtectionStrength) or {}
    local pestPressure, pestExposureHours = nil, 0
    if pestsEnabled then
        pestPressure, pestExposureHours = evaluateGrowth(pestStart, pestGrowth, pestSegments)
    end

    -- Optimal Green Zone Growth Speed Boost (+15% speed):
    -- If Water >= 60 and Nutrients in optimal range and Weeds <= 30 and Pests <= 30
    local optMin = tonumber(nutrientParams.optimalMin) or 40
    local optMax = tonumber(nutrientParams.optimalMax) or 80
    local isWaterGood = (waterStart + water) * 0.5 >= 60
    local isNutrientGood = not nutrientsEnabled or ((nutrientStart + (nutrients or nutrientStart)) * 0.5 >= optMin and (nutrientStart + (nutrients or nutrientStart)) * 0.5 <= optMax)
    local isWeedsGood = not weedsEnabled or averageWeeds <= 30
    local isPestsGood = not pestsEnabled or (pestStart + (pestPressure or pestStart)) * 0.5 <= 30

    local optimalBonusHoursDelta = 0
    if isWaterGood and isNutrientGood and isWeedsGood and isPestsGood and hours > 0 then
        -- 15% growth boost during optimal green zone time
        optimalBonusHoursDelta = hours * 0.15
    end

    local penaltyRates = cfg.GrowthPenaltyPerDeficitHour or {}
    local waterPenaltyRate = math.max(0, tonumber(penaltyRates.water) or 0)
    local nutrientPenaltyRate = math.max(0, tonumber(penaltyRates.nutrients) or 0)
    local rateScale = math.max(1, waterPenaltyRate + nutrientPenaltyRate)
    local rawGrowthPenalty = (waterDeficitHours * waterPenaltyRate
        + nutrientDeficitHours * nutrientPenaltyRate) / rateScale
    -- Subtract optimal growth bonus from raw penalty (can speed up growth)
    local netGrowthPenaltyDelta = rawGrowthPenalty - optimalBonusHoursDelta
    local growthPenalty = Utils.Clamp(netGrowthPenaltyDelta, -hours * 0.15, hours)
    local stressFactor = criticalFactor(record, lastCare, now, growthPenalty)
    local weightedWaterDeficit = waterDeficitHours * stressFactor
    local weightedNutrientDeficit = nutrientDeficitHours * stressFactor
    local pestDamageDelta = pestsEnabled
        and pestExposureHours * (tonumber(cfg.PestDamagePerHour) or 0) * stressFactor
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
        waterProtectionStrength = waterProtectionStrength,
        waterProtectionUntil = waterProtectionUntil,
        waterProtectionTier = data.waterProtectionTier,
        waterProtectionItem = data.waterProtectionItem,
        nutrientProtectionStrength = nutrientProtectionStrength,
        nutrientProtectionUntil = nutrientProtectionUntil,
        nutrientProtectionTier = data.nutrientProtectionTier,
        nutrientProtectionItem = data.nutrientProtectionItem,
        weedProtectionStrength = weedProtectionStrength,
        weedProtectionUntil = weedProtectionUntil,
        weedProtectionTier = data.weedProtectionTier,
        weedProtectionItem = data.weedProtectionItem,
        pestProtectionStrength = pestProtectionStrength,
        pestProtectionUntil = pestProtectionUntil,
        pestProtectionTier = data.pestProtectionTier,
        pestProtectionItem = data.pestProtectionItem,
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

function Conditions.Evaluate(record, now)
    if Sonar.CropClock and Sonar.CropClock.IsV2(record) then
        return evaluateCycle(record, now or Sonar.Time.Now())
    end
    return evaluateLegacy(record, now)
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
