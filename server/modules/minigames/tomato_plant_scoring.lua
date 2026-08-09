--[[
    sonar_farm - Tomato Initial Planting scoring (server-pure)

    The NUI sends bounded, normalized interaction samples. This module validates
    and recomputes the four outcomes from those samples; client summaries and
    displayed feedback are never trusted. It deliberately has no FiveM globals so
    the exact scoring path can run in the dependency-free regression suite.
]]

TomatoPlantScoring = TomatoPlantScoring or {}

local STEP_ORDER = { 'prepare', 'place', 'cover', 'water' }
local STEP_SET = { prepare = true, place = true, cover = true, water = true }
local SCENE_WIDTH = 2048
local SCENE_HEIGHT = 1536

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function round(value, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor(value * power + 0.5) / power
end

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function scoreBand(score)
    if score >= 85 then return 'excellent' end
    if score >= 60 then return 'good' end
    return 'needs-attention'
end

local function validateSample(sample, previousTime)
    if type(sample) ~= 'table' then return false end
    if not finite(sample.t) or sample.t < 0 or sample.t < previousTime then return false end
    if not finite(sample.x) or sample.x < 0 or sample.x > 1 then return false end
    if not finite(sample.y) or sample.y < 0 or sample.y > 1 then return false end
    if sample.pressure ~= nil and (not finite(sample.pressure) or sample.pressure < 0 or sample.pressure > 1) then
        return false
    end
    if sample.tilt ~= nil and (not finite(sample.tilt) or sample.tilt < -1 or sample.tilt > 1) then
        return false
    end
    if sample.side ~= nil and sample.side ~= -1 and sample.side ~= 0 and sample.side ~= 1 then
        return false
    end
    if sample.down ~= nil and type(sample.down) ~= 'boolean' then return false end
    if sample.pouring ~= nil and type(sample.pouring) ~= 'boolean' then return false end
    if sample.keyboard ~= nil and type(sample.keyboard) ~= 'boolean' then return false end
    return true
end

local function flagSet(flags, bit)
    return math.floor(flags / bit) % 2 == 1
end

local function decodeSample(sample)
    if type(sample) ~= 'table' or sample[1] == nil then return sample end

    local bucket, x, y = sample[1], sample[2], sample[3]
    local flags, tilt, pressure = sample[4], sample[5], sample[6]
    if not finite(bucket) or bucket < 0 or bucket > 65535 or bucket % 1 ~= 0 then return nil end
    if not finite(x) or x < 0 or x > SCENE_WIDTH then return nil end
    if not finite(y) or y < 0 or y > SCENE_HEIGHT then return nil end
    if not finite(flags) or flags < 0 or flags > 15 or flags % 1 ~= 0 then return nil end
    if not finite(tilt) or tilt < -90 or tilt > 90 then return nil end
    if not finite(pressure) or pressure < 0 or pressure > 255 then return nil end

    local normalizedX = x / SCENE_WIDTH
    return {
        t = bucket * 50,
        x = normalizedX,
        y = y / SCENE_HEIGHT,
        down = flagSet(flags, 1),
        pouring = flagSet(flags, 2),
        keyboard = flagSet(flags, 4),
        pressure = pressure / 255,
        tilt = tilt / 90,
        side = normalizedX < 0.5 and -1 or 1,
    }
end

--- Validate and copy the evidence shape used by every scorer.
---@param step string
---@param trace table
---@param config table
---@return table|nil normalized
---@return string|nil reason
function TomatoPlantScoring.ValidateTrace(step, trace, config)
    if not STEP_SET[step] or type(trace) ~= 'table' or type(trace.samples) ~= 'table' then
        return nil, 'invalid_shape'
    end

    local maxSamples = config.maxSamplesPerStep or 400
    if #trace.samples < 2 or #trace.samples > maxSamples then
        return nil, 'invalid_sample_count'
    end

    local duration = tonumber(trace.durationMs)
    local minimum = config.minimumStepDurationMs and config.minimumStepDurationMs[step] or 0
    local maximum = config.maximumStepDurationMs or 120000
    if not finite(duration) or duration < minimum or duration > maximum then
        return nil, 'invalid_duration'
    end
    local sampleInterval = config.sampleIntervalMs or 50
    if #trace.samples > math.ceil(duration / sampleInterval) + 2 then
        return nil, 'sample_rate_exceeded'
    end

    local copied = {}
    local previousTime = -1
    for index, rawSample in ipairs(trace.samples) do
        local sample = decodeSample(rawSample)
        if not validateSample(sample, previousTime) then
            return nil, ('invalid_sample_%d'):format(index)
        end
        if sample.t > duration + 250 then
            return nil, 'sample_after_duration'
        end
        previousTime = sample.t
        copied[index] = {
            t = round(sample.t, 0),
            x = round(sample.x, 4),
            y = round(sample.y, 4),
            down = sample.down == true,
            pouring = sample.pouring == true,
            keyboard = sample.keyboard == true,
            pressure = sample.pressure and round(sample.pressure, 3) or 0,
            tilt = sample.tilt and round(sample.tilt, 3) or 0,
            side = sample.side or 0,
        }
    end

    return { durationMs = round(duration, 0), samples = copied }
end

local function scorePrepare(trace)
    local sectors, active, overdug, ideal = {}, 0, 0, 0
    local centerX, centerY = 0.50, 750 / SCENE_HEIGHT

    for _, sample in ipairs(trace.samples) do
        if sample.down then
            active = active + 1
            local dx, dy = sample.x - centerX, sample.y - centerY
            local radius = math.sqrt(dx * dx + dy * dy)
            local angle = math.atan(dy, dx)
            local sector = math.floor(((angle + math.pi) / (2 * math.pi)) * 12) + 1
            if radius >= 0.035 and radius <= 0.13 then
                sectors[clamp(sector, 1, 12)] = true
            end
            if radius >= 0.055 and radius <= 0.105 then ideal = ideal + 1 end
            if radius > 0.145 then overdug = overdug + 1 end
        end
    end

    local covered = 0
    for _ in pairs(sectors) do covered = covered + 1 end
    local coverage = covered / 12
    local precision = active > 0 and ideal / active or 0
    local overdig = active > 0 and overdug / active or 1
    local score = clamp(coverage * 62 + precision * 30 + (1 - clamp(overdig * 3, 0, 1)) * 8, 0, 100)

    return score, {
        depth = scoreBand(score),
        coverage = round(coverage, 3),
        overdig = round(overdig, 3),
    }
end

local function scorePlace(trace)
    local samples = trace.samples
    local last = samples[#samples]
    local targetX, targetY = 0.50, 720 / SCENE_HEIGHT
    local finalDistance = distance(last.x, last.y, targetX, targetY)
    local alignment = clamp(1 - finalDistance / 0.14, 0, 1)
    local vertical = clamp(1 - math.abs(last.tilt), 0, 1)

    local movement = 0
    local start = math.max(2, #samples - 5)
    for index = start, #samples do
        local previous = samples[index - 1]
        local current = samples[index]
        movement = movement + distance(previous.x, previous.y, current.x, current.y)
    end
    local settle = clamp(1 - movement / 0.20, 0, 1)
    local score = clamp(alignment * 70 + vertical * 20 + settle * 10, 0, 100)

    return score, {
        alignment = scoreBand(score),
        offset = round(finalDistance, 3),
        tilt = round(math.abs(last.tilt), 3),
    }
end

local function scoreCover(trace)
    local grid, active, hard = {}, 0, 0
    local left, right = 0, 0
    local keyboard = false

    for _, sample in ipairs(trace.samples) do
        if sample.down then
            keyboard = keyboard or sample.keyboard
            active = active + 1
            if sample.x < 0.5 then left = left + 1 else right = right + 1 end
            local gx = clamp(math.floor(sample.x * 8) + 1, 1, 8)
            local gy = clamp(math.floor(sample.y * 4) + 1, 1, 4)
            if sample.y >= 0.34 and sample.y <= 0.58 then
                grid[('%d:%d'):format(gx, gy)] = true
            end
            if sample.pressure > 0.78 then hard = hard + 1 end
        end
    end

    local cells = 0
    for _ in pairs(grid) do cells = cells + 1 end
    local coverage = clamp(cells / (keyboard and 4 or 18), 0, 1)
    local balance = active > 0 and 1 - math.abs(left - right) / active or 0
    local compaction = active > 0 and hard / active or 1
    local score = clamp(coverage * 58 + balance * 27 + (1 - clamp(compaction * 2, 0, 1)) * 15, 0, 100)

    return score, {
        aeration = scoreBand(score),
        coverage = round(coverage, 3),
        compaction = round(compaction, 3),
    }
end

local function scoreWater(trace)
    local grid, pouring, outside = {}, 0, 0
    local targetX, targetY = 0.50, 645 / SCENE_HEIGHT

    for _, sample in ipairs(trace.samples) do
        if sample.pouring then
            pouring = pouring + 1
            local ellipse = ((sample.x - targetX) / 0.108) ^ 2
                + ((sample.y - targetY) / 0.082) ^ 2
            if ellipse <= 1 then
                local gx = clamp(math.floor((sample.x - 0.392) / 0.215 * 6) + 1, 1, 6)
                local gy = clamp(math.floor((sample.y - 0.338) / 0.163 * 4) + 1, 1, 4)
                grid[('%d:%d'):format(gx, gy)] = true
            else
                outside = outside + 1
            end
        end
    end

    local cells = 0
    for _ in pairs(grid) do cells = cells + 1 end
    local coverage = clamp(cells / 16, 0, 1)
    local spill = pouring > 0 and outside / pouring or 1
    local targetSamples = trace.durationMs / 50 * 0.45
    local amount = clamp(1 - math.abs(pouring - targetSamples) / math.max(targetSamples, 1), 0, 1)
    local score = clamp(coverage * 60 + amount * 25 + (1 - clamp(spill * 2, 0, 1)) * 15, 0, 100)

    return score, {
        hydration = scoreBand(score),
        coverage = round(coverage, 3),
        spill = round(spill, 3),
    }
end

local SCORERS = {
    prepare = scorePrepare,
    place = scorePlace,
    cover = scoreCover,
    water = scoreWater,
}

---@param step string
---@param trace table
---@param config table
---@return table|nil result
---@return string|nil reason
function TomatoPlantScoring.ScoreStep(step, trace, config)
    local normalized, reason = TomatoPlantScoring.ValidateTrace(step, trace, config)
    if not normalized then return nil, reason end

    local score, metrics = SCORERS[step](normalized)
    score = round(score, 1)
    return {
        step = step,
        score = score,
        band = scoreBand(score),
        metrics = metrics,
        trace = normalized,
    }
end

---@param steps table keyed by step
---@param config table
---@param interruptionPenalty? number
---@return table|nil result
---@return string|nil reason
function TomatoPlantScoring.Finalize(steps, config, interruptionPenalty)
    local weights = config.stepWeights or {}
    local total = 0
    local outcomes = {}

    for _, step in ipairs(STEP_ORDER) do
        local result = steps and steps[step]
        if type(result) ~= 'table' or not finite(result.score) then
            return nil, ('missing_%s'):format(step)
        end
        total = total + result.score * (weights[step] or 0)
        for key, value in pairs(result.metrics or {}) do
            if key == 'depth' or key == 'alignment' or key == 'aeration' or key == 'hydration' then
                outcomes[key] = value
            end
        end
    end

    total = clamp(total - (interruptionPenalty or 0), 0, config.qualityCap or 100)
    total = round(total, 1)
    return {
        score = total,
        band = scoreBand(total),
        outcomes = outcomes,
    }
end

