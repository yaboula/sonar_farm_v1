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
    now = now or Sonar.Time.Now()

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
