--[[
    sonar_farm - Plant physiology evaluator (shared)
    Water, health and spoilage derived lazily from timestamps, exactly like
    growth: no ticks. A crop "lives" between interactions and its real condition
    is computed the moment someone looks at it.

    Model:
      - Water decays from data.lastCare at crop.water.decayPerHour.
      - Once water hits zero the crop starts losing health; droughtTolerance
        dampens how fast. No health means the crop is dead.
      - A mature, unharvested crop accumulates spoilage, which lowers quality.

    Shared because the client renders withered/dead states and filters its target
    options from the same numbers. Evaluate is pure; the mutators (Apply, Water)
    live server-side only, in server/modules/farming/physiology.lua.
]]

Physiology = Physiology or {}

local CROP_STATE = Sonar.Constants.CROP_STATE
local Utils = Sonar.Utils

-- Fallbacks when a crop definition omits physiology values.
local DEFAULT_WATER = { decayPerHour = 15, droughtTolerance = 0.5 }
local DEFAULT_SPOILAGE_PER_HOUR = 5

-- A fully dry crop loses at most this many health points per hour, before
-- drought tolerance dampens it.
local MAX_HEALTH_LOSS_PER_HOUR = 20

-- Below this health the crop looks withered but is still recoverable.
local WITHERED_HEALTH = 40

-- Maturity is historical. Once a specific in-memory record has crossed 100%,
-- its first mature timestamp cannot move unless that record is replaced by a
-- server delta. Weak keys keep this memo bounded by the record cache lifecycle.
local maturityMemo = setmetatable({}, { __mode = 'k' })

local function matureAtFor(record, now, isMature)
    local persisted = tonumber(record.data and record.data.maturedAt)
    if persisted then return persisted end
    if maturityMemo[record] then return maturityMemo[record] end
    local plantedAt = tonumber(record.planted_at) or now
    if not isMature and (Growth.Evaluate(record, now).progress or 0) < 1 then return nil end
    local low, high = plantedAt, now
    while low < high do
        local middle = math.floor((low + high) * 0.5)
        if Growth.Evaluate(record, middle).progress >= 1 then high = middle else low = middle + 1 end
    end
    maturityMemo[record] = high
    return high
end

--- Resolve the physiology parameters for a record.
---@param record table
---@return table water
---@return number spoilagePerHour
local function paramsFor(record)
    local def = Config.Crops and Config.Crops[record.crop_type]
    local water = (def and def.water) or DEFAULT_WATER
    local spoilage = (def and def.spoilagePerHour) or DEFAULT_SPOILAGE_PER_HOUR
    return water, spoilage
end

--- Evaluate a crop's condition at a point in time. Pure: does not mutate.
---@param record table
---@param now? number unix seconds (defaults to server-aligned now)
---@return table condition { water, health, spoilage, state, progress, stageIndex }
function Physiology.Evaluate(record, now)
    now = now or Sonar.Time.Now()

    if record.state == CROP_STATE.PLANTING or record.state == CROP_STATE.PLANTING_FAILED then
        return {
            water = 0,
            health = 100,
            spoilage = 0,
            state = record.state,
            progress = 0,
            stageIndex = 1,
        }
    end

    local data = record.data or {}
    local water = tonumber(data.water) or 100
    local health = tonumber(data.health) or 100
    local spoilage = tonumber(data.spoilage) or 0

    local params, spoilagePerHour = paramsFor(record)
    local lastCare = tonumber(data.lastCare) or record.planted_at or now
    local hours = math.max(0, now - lastCare) / 3600
    local advanced = Sonar.Conditions and Sonar.Conditions.IsAdvancedCareEnabled()
    local cycleV2 = Sonar.CropClock and Sonar.CropClock.IsV2(record)
    local trajectory = (advanced or cycleV2) and Sonar.Conditions.Evaluate(record, now) or nil

    if now > lastCare then
        local newWater = (advanced or cycleV2) and trajectory.water
            or Utils.Clamp(water - (params.decayPerHour * hours), 0, 100)

        if cycleV2 then
            local cycleCfg = Config.Farming.AdvancedCare.Cycle or {}
            local cropCycle = Config.Crops and Config.Crops[record.crop_type]
                and Config.Crops[record.crop_type].cycle or {}
            local tolerance = Utils.Clamp(tonumber(cropCycle.droughtTolerance)
                or params.droughtTolerance or 0.5, 0, 0.95)
            local dryLoss = (tonumber(trajectory.waterDryCycle) or 0)
                * (tonumber(cycleCfg.DryHealthLossPerCycle) or 0) * (1 - tolerance)
            local nutrientLoss = advanced and (tonumber(trajectory.nutrientCriticalCycle) or 0)
                * (tonumber(cycleCfg.NutrientHealthLossPerCycle) or 0) or 0
            local pestLoss = advanced and (tonumber(trajectory.pestDamageDelta) or 0) or 0
            health = Utils.Clamp(health - dryLoss - nutrientLoss - pestLoss, 0, 100)
        else
            -- Health only drops during the portion of time the crop spent dry.
            local hoursUntilDry = (params.decayPerHour > 0) and (water / params.decayPerHour) or math.huge
            local dryHours = advanced and trajectory.waterDryHours or math.max(0, hours - hoursUntilDry)
            if dryHours > 0 then
                local tolerance = Utils.Clamp(params.droughtTolerance or 0.5, 0, 0.95)
                health = Utils.Clamp(health - (dryHours * MAX_HEALTH_LOSS_PER_HOUR * (1 - tolerance)), 0, 100)
            end
            if advanced then
                local cfg = Config.Farming.AdvancedCare or {}
                local nutrientLoss = trajectory.nutrientDeficitHours
                    * (tonumber(cfg.NutrientHealthLossPerHour) or 0)
                health = Utils.Clamp(health - nutrientLoss - trajectory.pestDamageDelta, 0, 100)
            end
        end
        water = newWater
    end

    -- Advanced Care subtracts persisted and pending stress penalties. With the
    -- feature disabled this remains the original care-independent formula.
    -- Reuse the already computed trajectory. This is important on the client:
    -- target predicates may ask for a condition frequently, and V2 trajectory
    -- integration is the expensive part of the calculation.
    local growth = Growth.Evaluate(record, now, trajectory)

    -- Spoilage accrues only after maturity.
    local maturedAt
    if growth.progress >= 1 then
        if cycleV2 then
            maturedAt = matureAtFor(record, now, true) or now
            local cycleDef = Config.Crops and Config.Crops[record.crop_type]
                and Config.Crops[record.crop_type].cycle or {}
            spoilage = Utils.Clamp(Sonar.CropClock.Between(record, maturedAt, now)
                * (tonumber(cycleDef.spoilage) or 0), 0, 100)
        else
            local penaltySeconds = advanced
                and ((tonumber(data.growthPenaltyHours) or 0) + trajectory.growthPenaltyHoursDelta) * 3600
                or 0
            local matureAt = (record.planted_at or now) + (record.growth_time or 0) + penaltySeconds
            local matureHours = math.max(0, now - matureAt) / 3600
            spoilage = Utils.Clamp(matureHours * spoilagePerHour, 0, 100)
        end
    end

    local state
    if health <= 0 then
        state = CROP_STATE.DEAD
    elseif health < WITHERED_HEALTH then
        state = CROP_STATE.WITHERED
    else
        state = growth.state
    end

    -- V2 keeps full precision in the authoritative JSON baseline so settling a
    -- long interval once or in many lazy evaluations produces the same state.
    -- Presentation layers already round their own values.
    local function stored(value, places)
        return cycleV2 and value or Utils.Round(value, places)
    end
    local result = {
        water = stored(water, 1),
        health = stored(health, 1),
        spoilage = stored(spoilage, 1),
        state = state,
        progress = growth.progress,
        stageIndex = growth.stageIndex,
        maturedAt = maturedAt,
    }
    if advanced then
        result.nutrients = trajectory.nutrients and stored(trajectory.nutrients, 1) or nil
        result.weedCover = trajectory.weedCover and stored(trajectory.weedCover, 1) or nil
        result.pestPressure = trajectory.pestPressure and stored(trajectory.pestPressure, 1) or nil
        if cycleV2 then
            local nominal = Sonar.CropClock.Between(record, tonumber(record.planted_at) or now, now)
            local bonus = tonumber(Config.Farming.AdvancedCare.Cycle.GreenGrowthBonus) or 0.20
            result.growthAdjustmentRatio = Utils.Clamp(
                (tonumber(data.growthAdjustmentRatio) or 0)
                    + (tonumber(trajectory.growthAdjustmentRatioDelta) or 0),
                -nominal * bonus, nominal
            )
        else
            result.growthPenaltyHours = Utils.Round(
                Utils.Clamp(
                    (tonumber(data.growthPenaltyHours) or 0) + trajectory.growthPenaltyHoursDelta,
                    -hours * 0.15,
                    hours
                ),
                4
            )
        end
        result.waterStressAccumulated = stored(Utils.Clamp(
            (tonumber(data.waterStressAccumulated) or 0) + trajectory.waterStressDelta,
            0,
            100
        ), 2)
        result.nutrientStressAccumulated = trajectory.enabled.nutrients and stored(Utils.Clamp(
            (tonumber(data.nutrientStressAccumulated) or 0) + trajectory.nutrientStressDelta,
            0,
            100
        ), 2) or nil
        result.pestDamageAccumulated = trajectory.enabled.pests and stored(Utils.Clamp(
            (tonumber(data.pestDamageAccumulated) or 0) + trajectory.pestDamageDelta,
            0,
            100
        ), 2) or nil
        result.overfertilizeExcess = trajectory.enabled.nutrients
            and Utils.Round(Utils.Clamp(tonumber(data.overfertilizeExcess) or 0, 0, 100), 2)
            or nil
        result.waterProtectionStrength = trajectory.waterProtectionStrength
        result.waterProtectionUntil = trajectory.waterProtectionUntil
        result.waterProtectionTier = trajectory.waterProtectionTier
        result.waterProtectionItem = trajectory.waterProtectionItem
        result.nutrientProtectionStrength = trajectory.nutrientProtectionStrength
        result.nutrientProtectionUntil = trajectory.nutrientProtectionUntil
        result.nutrientProtectionTier = trajectory.nutrientProtectionTier
        result.nutrientProtectionItem = trajectory.nutrientProtectionItem
        result.weedProtectionStrength = trajectory.weedProtectionStrength
        result.weedProtectionUntil = trajectory.weedProtectionUntil
        result.weedProtectionTier = trajectory.weedProtectionTier
        result.weedProtectionItem = trajectory.weedProtectionItem
        result.pestProtectionStrength = trajectory.pestProtectionStrength
        result.pestProtectionUntil = trajectory.pestProtectionUntil
        result.pestProtectionTier = trajectory.pestProtectionTier
        result.pestProtectionItem = trajectory.pestProtectionItem
        result.bandExposure = trajectory.bandExposure
    elseif cycleV2 then
        result.growthAdjustmentRatio = (
            (tonumber(data.growthAdjustmentRatio) or 0)
                + (tonumber(trajectory.growthAdjustmentRatioDelta) or 0))
        result.waterProtectionStrength = trajectory.waterProtectionStrength
        result.waterProtectionUntil = trajectory.waterProtectionUntil
        result.waterProtectionTier = trajectory.waterProtectionTier
        result.waterProtectionItem = trajectory.waterProtectionItem
    end
    return result
end
