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

    local data = record.data or {}
    local water = tonumber(data.water) or 100
    local health = tonumber(data.health) or 100
    local spoilage = tonumber(data.spoilage) or 0

    local params, spoilagePerHour = paramsFor(record)
    local lastCare = tonumber(data.lastCare) or record.planted_at or now
    local hours = math.max(0, now - lastCare) / 3600

    if hours > 0 then
        local newWater = Utils.Clamp(water - (params.decayPerHour * hours), 0, 100)

        -- Health only drops during the portion of time the crop spent dry.
        local hoursUntilDry = (params.decayPerHour > 0) and (water / params.decayPerHour) or math.huge
        local dryHours = math.max(0, hours - hoursUntilDry)
        if dryHours > 0 then
            local tolerance = Utils.Clamp(params.droughtTolerance or 0.5, 0, 0.95)
            health = Utils.Clamp(health - (dryHours * MAX_HEALTH_LOSS_PER_HOUR * (1 - tolerance)), 0, 100)
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
    elseif health < WITHERED_HEALTH then
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
