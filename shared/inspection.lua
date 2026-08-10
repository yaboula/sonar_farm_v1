--[[
    sonar_farm - Pure crop inspection snapshot

    Produces the versioned domain payload consumed by the focus-free inspection
    NUI. Every value comes from the same shared Growth/Physiology/Conditions
    evaluators used by gameplay; the UI never invents curves or thresholds.
]]

Sonar = Sonar or {}

local Inspection = {}
local Utils = Sonar.Utils
local CROP_STATE = Sonar.Constants.CROP_STATE
local etaMemo = setmetatable({}, { __mode = 'k' })

local function etaSignature(record)
    local data = record.data or {}
    return table.concat({
        tostring(record.state), tostring(record.planted_at), tostring(record.growth_time),
        tostring(data.lastCare), tostring(data.growthAdjustmentRatio), tostring(data.growthPenaltyHours),
        tostring(data.water), tostring(data.health), tostring(data.nutrients),
        tostring(data.weedCover), tostring(data.pestPressure),
        tostring(data.waterProtectionStrength), tostring(data.waterProtectionUntil),
        tostring(data.nutrientProtectionStrength), tostring(data.nutrientProtectionUntil),
        tostring(data.weedProtectionStrength), tostring(data.weedProtectionUntil),
        tostring(data.pestProtectionStrength), tostring(data.pestProtectionUntil),
    }, '|')
end

local METRIC_KEYS = { 'water', 'nutrients', 'weeds', 'pests' }

local function config()
    return Config.Inspection or {}
end

local function definition(record)
    return Config.Crops and Config.Crops[record.crop_type] or {}
end

local function shallowCopy(value)
    local result = {}
    for key, entry in pairs(value or {}) do result[key] = entry end
    return result
end

local function conditionEnabled(record, key)
    if key == 'water' then return true end
    return Sonar.Conditions.IsAdvancedCareEnabled()
        and Sonar.Conditions.IsEnabled(record, key == 'weeds' and 'weeds' or key == 'pests' and 'pests' or 'nutrients')
end

local function valueFor(condition, key, enabled)
    if not enabled then return 0 end
    if key == 'weeds' then return tonumber(condition.weedCover) or 0 end
    if key == 'pests' then return tonumber(condition.pestPressure) or 0 end
    return tonumber(condition[key]) or 0
end

local function stageLabel(record, condition)
    if condition.state == CROP_STATE.PLANTING then return 'Planting' end
    if condition.state == CROP_STATE.PLANTING_FAILED then return 'Planting interrupted' end
    if condition.state == CROP_STATE.DEAD then return 'Dead' end
    local stages = definition(record).stages or {}
    local stage = stages[condition.stageIndex or 1] or stages[#stages]
    return stage and stage.label or (condition.progress >= 1 and 'Harvest ready' or 'Growing')
end

local function statusFor(record, key, current, enabled)
    if not enabled then return 'unaffected' end
    local cycleV2 = Sonar.CropClock.IsV2(record)
    local cycleCfg = Config.Farming.AdvancedCare.Cycle or {}
    if key == 'water' then
        local critical = cycleV2 and tonumber(cycleCfg.Water and cycleCfg.Water.critical) or 30
        local green = cycleV2 and tonumber(cycleCfg.Water and cycleCfg.Water.green) or 60
        if current < (critical or 35) then return 'critical' end
        if current < (green or 60) then return 'low' end
        return 'stable'
    end
    if key == 'nutrients' then
        -- 0-30 risk, 31-75 good, 76-100 risk (overfertilize)
        local params = definition(record).nutrients or {}
        local minimum = tonumber(params.optimalMin) or 30
        local maximum = tonumber(params.optimalMax) or 75
        if cycleV2 then
            local margin = tonumber(cycleCfg.NutrientWatchMargin) or 20
            if current < minimum - margin or current > maximum + margin then return 'critical' end
            if current < minimum or current > maximum then return current > maximum and 'high' or 'low' end
        elseif current > maximum then return 'high'
        elseif current < minimum then return 'critical' end
        return 'stable'
    end
    local green = cycleV2 and tonumber(cycleCfg.Pressure and cycleCfg.Pressure.green) or 30
    local critical = cycleV2 and tonumber(cycleCfg.Pressure and cycleCfg.Pressure.critical) or 60
    if current > (critical or 50) then return 'severe' end
    if current > (green or 20) then return 'elevated' end
    return 'low'
end

local function sample(record, at)
    local condition = Physiology.Evaluate(record, at)
    local result = {
        at = at,
        progress = Utils.Round((condition.progress or 0) * 100, 2),
        health = Utils.Round(condition.health or 0, 2),
    }
    for _, key in ipairs(METRIC_KEYS) do
        result[key] = Utils.Round(valueFor(condition, key, conditionEnabled(record, key)), 2)
    end
    return result, condition
end

local function seriesFor(record, now)
    local cfg = config()
    local data = record.data or {}
    local plantedAt = tonumber(record.planted_at) or now
    local historySeconds = Sonar.CropClock.ScaledConfigSeconds(record,
        cfg.HistorySeconds or 600, cfg.HistoryCycleRatio or 0.25)
    -- Records persist a condition baseline at lastCare. Values before that
    -- baseline cannot be reconstructed truthfully, so the historical chart
    -- starts at the newest reliable boundary and ends at the current sample.
    local lastCare = math.min(now, tonumber(data.lastCare) or plantedAt)
    local windowStart = math.max(plantedAt, lastCare, now - historySeconds)
    local windowLen = math.max(1, now - windowStart)

    -- Adaptive step: ~50 samples across the window, clamped 5-120 s.
    local targetSamples = tonumber(cfg.TargetSamples) or 50
    local step = math.max(5, math.min(120, math.floor(windowLen / targetSamples)))

    local samples = {}
    local at = windowStart
    while at < now do
        local point = sample(record, at)
        point.phase = 'history'
        samples[#samples + 1] = point
        at = math.min(now, at + step)
    end
    local current = sample(record, now)
    current.phase = 'now'
    samples[#samples + 1] = current

    return {
        plantedAt    = plantedAt,
        lastCare     = lastCare,
        windowStart  = windowStart,
        windowLen    = windowLen,
        historyStart = windowStart,
        now          = now,
        forecastEnd  = now,
        samples      = samples,
    }
end


-- ---------------------------------------------------------------------------
-- Estimated quality and production (shared, mirrors Quality.Resolve / Quality.ResolveProduction)
-- These are estimates visible to the player NOW, not the authoritative harvest values.
-- ---------------------------------------------------------------------------
local function projectOutcome(record, current)
    if not Sonar.Conditions.IsAdvancedCareEnabled() then
        return nil
    end
    local cfg = Config.Quality or {}
    local health     = tonumber(current.health) or 100
    local spoilage   = tonumber(current.spoilage) or 0
    local defaultScore = tonumber(cfg.DefaultScore) or 75
    local skillScore = defaultScore
    local data = record.data or {}
    local plantingQuality = tonumber(data.plantingQuality)
        or tonumber(data.plantScore)
    if plantingQuality then
        local influence = Utils.Clamp(tonumber(cfg.PlantingInfluence) or 0, 0, 1)
        skillScore = defaultScore * (1 - influence) + Utils.Clamp(plantingQuality, 0, 100) * influence
    end

    -- Mirror Quality.Resolve using the default future harvest score plus the
    -- already-authoritative planting score when one exists.
    local cycleV2 = Sonar.CropClock.IsV2(record)
    local quality = skillScore  * (cycleV2 and 0.4 or (tonumber(cfg.ScoreWeight) or 0.6))
                  + health      * (cycleV2 and 0.6 or (tonumber(cfg.CareWeight)  or 0.4))
    quality = quality * (1 - Utils.Clamp(spoilage / 100, 0, 1))

    local waterDefect    = tonumber(current.waterStressAccumulated)   or 0
    local nutrientDefect = (tonumber(current.nutrientStressAccumulated) or 0)
                         + (tonumber(current.overfertilizeExcess)       or 0)
    local pestDefect     = tonumber(current.pestDamageAccumulated)     or 0
    local defectScore    = Utils.Clamp(math.max(waterDefect, nutrientDefect, pestDefect), 0, 100)
    quality = quality * (1 - defectScore / 100 * Utils.Clamp(tonumber(cfg.DefectWeight) or 0, 0, 1))
    quality = Utils.Round(Utils.Clamp(quality, 0, 100), 1)

    -- Mirror Quality.ResolveProduction
    local weights       = cfg.ProductionWeights or {}
    local nutrientStress = tonumber(current.nutrientStressAccumulated) or 0
    local pestDamage    = tonumber(current.pestDamageAccumulated)     or 0
    local production    = 100
                        - nutrientStress * (tonumber(weights.nutrientStress) or 0)
                        - pestDamage     * (tonumber(weights.pestDamage)     or 0)
    production = Utils.Round(Utils.Clamp(production, 0, 100), 1)

    local tier = Utils.QualityTier(quality)
    local dominant = Sonar.Conditions.DominantDefect(current)

    return {
        quality         = quality,
        qualityTier     = tier.key,
        qualityLabel    = tier.label,
        production      = production,
        dominantDefect  = dominant ~= 'none' and dominant or nil,
        waterStress     = Utils.Round(waterDefect,    1),
        nutrientStress  = Utils.Round(nutrientDefect, 1),
        pestDamage      = Utils.Round(pestDefect,     1),
    }
end

local function thresholdsFor(record, key, enabled)
    if not enabled then return {} end
    local cycleV2 = Sonar.CropClock.IsV2(record)
    local cycleCfg = Config.Farming.AdvancedCare.Cycle or {}
    if key == 'water' then
        return {
            { value = cycleV2 and (cycleCfg.Water.critical or 35) or 30, label = 'Risk', tone = 'risk' },
            { value = cycleV2 and (cycleCfg.Water.green or 60) or 60, label = 'Good', tone = 'good' },
        }
    end
    if key == 'nutrients' then
        local params = definition(record).nutrients or {}
        return {
            { value = tonumber(params.optimalMin) or 30, label = 'Minimum', tone = 'good' },
            { value = tonumber(params.optimalMax) or 75, label = 'Maximum', tone = 'risk' },
        }
    end
    return {
        { value = cycleV2 and (cycleCfg.Pressure.green or 20) or 30, label = 'Watch', tone = 'watch' },
        { value = cycleV2 and (cycleCfg.Pressure.critical or 50) or 60, label = 'Risk', tone = 'risk' },
    }
end

local function readyAt(record, now, current)
    if record.state == CROP_STATE.PLANTING or record.state == CROP_STATE.PLANTING_FAILED then return nil end
    if current.state == CROP_STATE.DEAD then return nil end
    local plantedAt = tonumber(record.planted_at) or now
    if (current.progress or 0) >= 1 then
        if not Sonar.CropClock.IsV2(record) then
            local penalty = (tonumber(current.growthPenaltyHours) or 0) * 3600
            return math.floor(plantedAt + (tonumber(record.growth_time) or 0) + penalty)
        end
        return tonumber(current.maturedAt) or tonumber(record.data and record.data.maturedAt)
    end
    local useMemo = Sonar.CropClock.IsV2(record)
    local signature = useMemo and etaSignature(record) or nil
    local cached = useMemo and etaMemo[record] or nil
    if cached and cached.signature == signature then
        return cached.value ~= false and cached.value or nil
    end
    local maxEta = Sonar.CropClock.ScaledConfigSeconds(record,
        config().MaxEtaSeconds or 86400, config().MaxEtaCycles or 4)
    local high = now + math.max(60, maxEta)
    if (Growth.Evaluate(record, high).progress or 0) < 1 then
        if useMemo then etaMemo[record] = { signature = signature, value = false } end
        return nil
    end
    local low = now
    for _ = 1, 24 do
        local middle = math.floor((low + high) * 0.5)
        if Growth.Evaluate(record, middle).progress >= 1 then high = middle else low = middle + 1 end
    end
    if useMemo then etaMemo[record] = { signature = signature, value = high } end
    return high
end

local function diagnosis(record, now, current, future, horizonSeconds)
    if current.state == CROP_STATE.PLANTING_FAILED then
        return { cause = 'planting_failed', severity = 100, headline = 'PLANTING → INCOMPLETE', recommendation = 'RESUME OR CLEAR PLOT' }
    end
    if current.state == CROP_STATE.PLANTING then
        return { cause = 'planting', severity = 70, headline = 'PLANTING → IN PROGRESS', recommendation = 'RESUME PLANTING' }
    end
    if current.state == CROP_STATE.DEAD then
        local defect = Sonar.Conditions.DominantDefect(current):gsub('_', ' '):upper()
        return { cause = 'dead', severity = 100, headline = defect .. ' → CROP LOST', recommendation = 'CLEAR PLOT' }
    end
    if (current.progress or 0) >= 1 then
        return { cause = 'mature', severity = Utils.Round(current.spoilage or 0, 1), headline = 'MATURE CROP → SPOILAGE RISING', recommendation = 'HARVEST' }
    end

    local cfg = Config.Farming.AdvancedCare or {}
    local enabled = {
        nutrients = conditionEnabled(record, 'nutrients'),
        weeds = conditionEnabled(record, 'weeds'),
        pests = conditionEnabled(record, 'pests'),
    }
    local scores = {
        water = math.max(0, (future.waterStressAccumulated or 0) - (current.waterStressAccumulated or 0)),
        nutrients = enabled.nutrients and math.max(0,
            (future.nutrientStressAccumulated or 0) - (current.nutrientStressAccumulated or 0)
        ) or 0,
        pests = enabled.pests and math.max(0,
            (future.pestDamageAccumulated or 0) - (current.pestDamageAccumulated or 0)
        ) or 0,
        weeds = 0,
    }
    local waterThreshold = tonumber(cfg.WaterDeficitThreshold) or 35
    if (current.water or 0) <= waterThreshold then scores.water = scores.water + 50 end
    if enabled.nutrients then
        local params = definition(record).nutrients or {}
        if (current.nutrients or 0) < (tonumber(params.optimalMin) or 40) then scores.nutrients = scores.nutrients + 45 end
        if (current.nutrients or 0) > (tonumber(params.optimalMax) or 85) then scores.nutrients = scores.nutrients + 55 end
        scores.nutrients = scores.nutrients + math.max(0, tonumber(current.overfertilizeExcess) or 0)
    end
    if enabled.pests and (current.pestPressure or 0) >= (tonumber(cfg.MinimumPestPressure) or 8) then
        scores.pests = scores.pests + (current.pestPressure or 0) * 0.2
    end
    if enabled.weeds and (current.weedCover or 0) >= (tonumber(cfg.MinimumWeedCover) or 8) then
        local without = shallowCopy(record)
        without.data = shallowCopy(record.data)
        without.data.weedCover = 0
        local clean = Physiology.Evaluate(without, now + horizonSeconds)
        local causalLoss = math.max(0, (clean.water or 0) - (future.water or 0))
            + math.max(0, (clean.nutrients or 0) - (future.nutrients or 0))
            + math.max(0, (future.pestPressure or 0) - (clean.pestPressure or 0))
        scores.weeds = (current.weedCover or 0) * 0.2 + causalLoss * 4
    end

    local function crossingAt(key)
        local cropDefinition = definition(record)
        local step = math.max(1, math.min(tonumber(config().SampleSeconds) or 30,
            math.max(1, math.floor(horizonSeconds / 20))))
        local function crossed(condition)
            if key == 'water' then return (condition.water or 0) <= waterThreshold end
            if key == 'nutrients' then
                local params = cropDefinition.nutrients or {}
                return (condition.nutrients or 0) < (tonumber(params.optimalMin) or 40)
                    or (condition.nutrients or 0) > (tonumber(params.optimalMax) or 85)
            end
            if key == 'weeds' then
                return (condition.weedCover or 0) >= (tonumber(cfg.MinimumWeedCover) or 8)
            end
            return (condition.pestPressure or 0) >= (tonumber(cfg.MinimumPestPressure) or 8)
        end
        if crossed(current) then return 0 end
        for offset = step, horizonSeconds, step do
            if crossed(Physiology.Evaluate(record, now + offset)) then return offset end
        end
        return math.huge
    end

    local order = { 'water', 'nutrients', 'pests', 'weeds' }
    local winner, highest, nearest = 'none', 0, nil
    for _, key in ipairs(order) do
        if scores[key] > highest + 0.001 then
            winner, highest, nearest = key, scores[key], nil
        elseif scores[key] > 0 and math.abs(scores[key] - highest) <= 0.001 then
            nearest = nearest or crossingAt(winner)
            local candidate = crossingAt(key)
            if candidate < nearest then winner, nearest = key, candidate end
        end
    end
    local copy = {
        water = { 'WATER DEFICIT → SLOWER GROWTH', 'WATER CROP' },
        nutrients = { 'NUTRIENT IMBALANCE → GROWTH STRESS', 'CHECK NUTRIENTS' },
        pests = { 'PEST PRESSURE → PRODUCTION DAMAGE', 'TREAT PESTS' },
        weeds = { 'WEEDS → FASTER WATER LOSS', 'REMOVE WEEDS' },
        none = { 'CONDITIONS → STABLE', 'NO CARE REQUIRED' },
    }
    return {
        cause = winner,
        severity = Utils.Round(Utils.Clamp(highest, 0, 100), 1),
        headline = copy[winner][1],
        recommendation = copy[winner][2],
    }
end

---@param record table
---@param now? number server-aligned Unix seconds
---@param options? table { includeSeries = boolean }
---@return table payload versioned inspection contract
function Inspection.Build(record, now, options)
    now = now or Sonar.Time.Now()
    options = options or {}
    local current = Physiology.Evaluate(record, now)
    local forecastSeconds = Sonar.CropClock.ScaledConfigSeconds(record,
        config().ForecastSeconds or 600, config().DiagnosisCycleRatio or 0.10)
    local future = Physiology.Evaluate(record, now + forecastSeconds)
    local matureAt = readyAt(record, now, current)
    local metrics = {}
    for _, key in ipairs(METRIC_KEYS) do
        local enabled = conditionEnabled(record, key)
        local currentValue = valueFor(current, key, enabled)
        local futureValue = valueFor(future, key, enabled)
        local metric = {
            key = key,
            label = key == 'weeds' and 'Weeds' or key == 'pests' and 'Pests'
                or key:sub(1, 1):upper() .. key:sub(2),
            value = Utils.Round(currentValue, 1),
            enabled = enabled,
            status = statusFor(record, key, currentValue, enabled),
            thresholds = thresholdsFor(record, key, enabled),
        }
        if key == 'water' then
            metric.protectionTier = current.waterProtectionTier
            metric.protectionUntil = current.waterProtectionUntil
        elseif key == 'nutrients' then
            metric.protectionTier = current.nutrientProtectionTier
            metric.protectionUntil = current.nutrientProtectionUntil
        elseif key == 'weeds' then
            metric.protectionTier = current.weedProtectionTier
            metric.protectionUntil = current.weedProtectionUntil
        elseif key == 'pests' then
            metric.protectionTier = current.pestProtectionTier
            metric.protectionUntil = current.pestProtectionUntil
        end
        metrics[#metrics + 1] = metric
    end

    local payload = {
        version = 1,
        subject = {
            id = record.id,
            crop = record.crop_type,
            label = definition(record).label or record.crop_type,
            stage = stageLabel(record, current),
            slot = ('%s · %s'):format(tostring(record.zone or 'field'), tostring(record.slot or 'free')),
            state = current.state,
            isMine = record.isMine and true or false,
        },
        timing = {
            serverNow = now,
            plantedAt = tonumber(record.planted_at) or now,
            lastCareAt = tonumber(record.data and record.data.lastCare) or tonumber(record.planted_at) or now,
            readyAt = matureAt,
            readyInSeconds = matureAt and math.max(0, matureAt - now) or nil,
            readySinceSeconds = matureAt and current.progress >= 1 and math.max(0, now - matureAt) or nil,
            forecastSeconds = forecastSeconds,
        },
        growth = Utils.Round((current.progress or 0) * 100, 1),
        health = Utils.Round(current.health or 0, 1),
        spoilage = Utils.Round(current.spoilage or 0, 1),
        metrics = metrics,
        diagnosis = diagnosis(record, now, current, future, forecastSeconds),
        outcome = projectOutcome(record, current),
    }
    if options.includeSeries ~= false then payload.series = seriesFor(record, now) end
    return payload
end

Sonar.Inspection = Inspection
