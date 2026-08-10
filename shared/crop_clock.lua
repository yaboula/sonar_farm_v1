--[[
    sonar_farm - Versioned crop-cycle clock

    V2 agricultural simulation is expressed as fractions of the crop's stored
    growth_time. Operational clocks (cooldowns, UI refresh, supplier workers)
    deliberately never use this module.
]]

Sonar = Sonar or {}

local CropClock = {}

function CropClock.Version(record)
    return math.floor(tonumber(record and record.data and record.data.simulationVersion) or 1)
end

function CropClock.IsV2(record)
    return CropClock.Version(record) >= 2
end

function CropClock.GrowthSeconds(record)
    return math.max(1, tonumber(record and record.growth_time) or 1)
end

function CropClock.RatioForSeconds(record, seconds)
    return math.max(0, tonumber(seconds) or 0) / CropClock.GrowthSeconds(record)
end

function CropClock.SecondsForRatio(record, ratio)
    return math.max(0, tonumber(ratio) or 0) * CropClock.GrowthSeconds(record)
end

function CropClock.Between(record, fromTime, toTime)
    return CropClock.RatioForSeconds(record, math.max(0, (tonumber(toTime) or 0) - (tonumber(fromTime) or 0)))
end

function CropClock.TimestampAfter(record, fromTime, ratio)
    return (tonumber(fromTime) or 0) + CropClock.SecondsForRatio(record, ratio)
end

function CropClock.ProtectionSeconds(record, effect)
    effect = effect or {}
    if CropClock.IsV2(record) then
        return CropClock.SecondsForRatio(record, effect.protectionCycleRatio)
    end
    return math.max(0, tonumber(effect.protectionHours) or 0) * 3600
end

function CropClock.ScaledConfigSeconds(record, legacySeconds, cycleRatio)
    if CropClock.IsV2(record) then
        return CropClock.SecondsForRatio(record, cycleRatio)
    end
    return math.max(0, tonumber(legacySeconds) or 0)
end

--- Build the persisted biological state for a newly created crop. Keeping this
--- here guarantees normal planting, minigame reservations and debug planting
--- all opt into the same simulation version and nutrient baseline.
---@param cropType string
---@param values? table
---@return table
function CropClock.NewData(cropType, values)
    local data = {}
    for key, value in pairs(values or {}) do data[key] = value end

    local version = math.floor(tonumber(Config.Farming
        and Config.Farming.NewCropSimulationVersion) or 1)
    data.simulationVersion = version
    if version >= 2 then
        local nutrients = Config.Crops and Config.Crops[cropType]
            and Config.Crops[cropType].nutrients or {}
        local optimalMin = tonumber(nutrients.optimalMin) or 40
        local optimalMax = tonumber(nutrients.optimalMax) or 80
        if data.nutrients == nil then data.nutrients = (optimalMin + optimalMax) * 0.5 end
        if data.weedCover == nil then data.weedCover = 0 end
        if data.pestPressure == nil then data.pestPressure = 0 end
        if data.growthAdjustmentRatio == nil then data.growthAdjustmentRatio = 0 end
        if data.waterStressAccumulated == nil then data.waterStressAccumulated = 0 end
        if data.nutrientStressAccumulated == nil then data.nutrientStressAccumulated = 0 end
        if data.pestDamageAccumulated == nil then data.pestDamageAccumulated = 0 end
        if data.overfertilizeExcess == nil then data.overfertilizeExcess = 0 end
    end
    return data
end

Sonar.CropClock = CropClock
