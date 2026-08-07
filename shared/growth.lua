--[[
    sonar_farm - Growth evaluator (shared)
    Pure, side-effect-free timestamp math. Given a crop record it derives the
    current progress and visual stage without mutating anything and without any
    tick. Callers evaluate lazily (on query / interaction / render).

    Shared on purpose: from Stage 4 the client predicts growth locally so an idle
    field costs zero network traffic. Client and server must run the exact same
    formula, so this lives in one file instead of being duplicated. The client can
    only mispredict what it *draws*; every action is still decided by the server.
]]

Growth = Growth or {}

local CROP_STATE = Sonar.Constants.CROP_STATE

--- Resolve the visual stages array for a record.
--- Priority: per-record override (record.data.stages) then Config.Crops[type].
---@param record table
---@return table[]|nil stages array of { ratio = number, ... }
local function resolveStages(record)
    if record.data and type(record.data.stages) == 'table' then
        return record.data.stages
    end
    local def = Config.Crops and Config.Crops[record.crop_type]
    if def and type(def.stages) == 'table' then
        return def.stages
    end
    return nil
end

--- Pick the stage index whose ratio threshold is the highest one <= progress.
---@param stages table[]|nil
---@param progress number 0..1
---@return number index 1-based (1 when no stages defined)
local function stageIndexFor(stages, progress)
    if not stages or #stages == 0 then return 1 end
    local index = 1
    for i, stage in ipairs(stages) do
        if progress >= (stage.ratio or 0) then
            index = i
        end
    end
    return index
end

--- Evaluate a crop's growth at a point in time.
---@param record table state record (needs planted_at, growth_time, crop_type)
---@param now? number unix seconds (defaults to server-aligned now)
---@return table result { elapsed, progress, stageIndex, state }
function Growth.Evaluate(record, now)
    now = now or Sonar.Time.Now()

    local elapsed = math.max(0, now - (record.planted_at or now))
    local growthTime = record.growth_time or 0

    local progress
    if growthTime > 0 then
        progress = Sonar.Utils.Clamp(elapsed / growthTime, 0, 1)
    else
        progress = 1
    end

    local stages = resolveStages(record)
    local stageIndex = stageIndexFor(stages, progress)

    local state
    if progress >= 1 then
        state = CROP_STATE.MATURE
    elseif progress > 0 then
        state = CROP_STATE.GROWING
    else
        state = CROP_STATE.PLANTED
    end

    return {
        elapsed = elapsed,
        progress = progress,
        stageIndex = stageIndex,
        state = state,
    }
end
