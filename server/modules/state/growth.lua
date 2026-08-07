--[[
    sonar_farm - Growth evaluator (server)
    Pure, side-effect-free timestamp math. Given a crop record it derives the
    current progress and visual stage without mutating anything and without any
    server tick. Callers evaluate lazily (on query / interaction).

    Physiology (watering / health / withering) arrives in Stage 3; here we only
    model deterministic time-based growth.
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
---@param now? number unix seconds (defaults to os.time())
---@return table result { elapsed, progress, stageIndex, state }
function Growth.Evaluate(record, now)
    now = now or os.time()

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
