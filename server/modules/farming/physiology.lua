--[[
    sonar_farm - Plant physiology (server)
    Water, health and spoilage, evaluated lazily from timestamps exactly like
    growth.lua: no server ticks. A crop "lives" between interactions and its
    real condition is derived the moment someone looks at it.

    Model:
      - Water decays from data.lastCare at crop.water.decayPerHour.
      - Once water hits zero the crop starts losing health; droughtTolerance
        dampens how fast. No health means the crop is dead.
      - A mature, unharvested crop accumulates spoilage, which lowers quality.

    Evaluate() is pure. Apply() is the only function that mutates state.
]]

Physiology = Physiology or {}

local CROP_STATE = Sonar.Constants.CROP_STATE
local Utils = Sonar.Utils

-- Fallbacks when a crop definition omits physiology values.
local DEFAULT_WATER = { decayPerHour = 15, droughtTolerance = 0.5 }
local DEFAULT_SPOILAGE_PER_HOUR = 5

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
---@param now? number unix seconds
---@return table condition { water, health, spoilage, state }
function Physiology.Evaluate(record, now)
    now = now or os.time()

    local data = record.data or {}
    local water = tonumber(data.water) or 100
    local health = tonumber(data.health) or 100
    local spoilage = tonumber(data.spoilage) or 0

    local params, spoilagePerHour = paramsFor(record)
    local lastCare = tonumber(data.lastCare) or record.planted_at or now
    local hours = math.max(0, now - lastCare) / 3600

    if hours > 0 then
        local waterLost = params.decayPerHour * hours
        local newWater = Utils.Clamp(water - waterLost, 0, 100)

        -- Health only drops during the portion of time the crop spent dry.
        local hoursUntilDry = (params.decayPerHour > 0) and (water / params.decayPerHour) or math.huge
        local dryHours = math.max(0, hours - hoursUntilDry)
        if dryHours > 0 then
            local tolerance = Utils.Clamp(params.droughtTolerance or 0.5, 0, 0.95)
            -- A fully dry crop loses up to 20 health points per hour, reduced by
            -- its drought tolerance.
            local healthLost = dryHours * 20 * (1 - tolerance)
            health = Utils.Clamp(health - healthLost, 0, 100)
        end

        water = newWater
    end

    -- Growth is independent of care: a neglected crop still ripens, it just
    -- ripens badly.
    local growth = Growth.Evaluate(record, now)

    -- Spoilage accrues only after maturity.
    if growth.progress >= 1 then
        local matureAt = (record.planted_at or now) + (record.growth_time or 0)
        local matureHours = math.max(0, now - matureAt) / 3600
        spoilage = Utils.Clamp(matureHours * spoilagePerHour, 0, 100)
    end

    local state
    if health <= 0 then
        state = CROP_STATE.DEAD
    elseif health < 40 then
        state = CROP_STATE.WITHERED
    else
        state = growth.state
    end

    return {
        water = Utils.Round(water, 1),
        health = Utils.Round(health, 1),
        spoilage = Utils.Round(spoilage, 1),
        state = state,
        progress = growth.progress,
        stageIndex = growth.stageIndex,
    }
end

--- Evaluate and commit the condition into hot state. Call this before any
--- action that depends on current water/health/state.
---@param record table
---@param now? number
---@return table condition
function Physiology.Apply(record, now)
    now = now or os.time()
    local condition = Physiology.Evaluate(record, now)

    State.Update(record.id, {
        state = condition.state,
        data = {
            water = condition.water,
            health = condition.health,
            spoilage = condition.spoilage,
            -- Advance the care clock so decay is not applied twice.
            lastCare = now,
        },
    })

    return condition
end

--- Water a crop: restore water and record the care for quality purposes.
---@param record table
---@param amount? number water points restored (default 100 = full)
---@param now? number
function Physiology.Water(record, amount, now)
    now = now or os.time()

    local data = record.data or {}
    local newWater = Utils.Clamp((tonumber(data.water) or 0) + (amount or 100), 0, 100)

    State.Update(record.id, {
        data = {
            water = newWater,
            lastCare = now,
            -- Care count feeds the quality formula: an actively tended crop
            -- yields better produce than a neglected one.
            careCount = (tonumber(data.careCount) or 0) + 1,
        },
    })
end
