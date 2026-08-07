--[[
    sonar_farm - Configuration validation (shared, pure)
    Validates structural invariants before the server accepts gameplay.
]]

Sonar = Sonar or {}

local ConfigValidation = {}

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function positive(errors, path, value, allowZero)
    local invalid = not finite(value)
        or (allowZero and value < 0)
        or (not allowZero and value <= 0)

    if invalid then
        errors[#errors + 1] = ('%s must be %s number.'):format(
            path,
            allowZero and 'a non-negative' or 'a positive'
        )
    end
end

local function nonEmptyString(errors, path, value)
    if type(value) ~= 'string' or value == '' then
        errors[#errors + 1] = path .. ' must be a non-empty string.'
    end
end

local function validateFramework(errors)
    local supported = { auto = true, ['qb-core'] = true, esx = true, qbox = true }
    if not supported[Config.Framework] then
        errors[#errors + 1] = 'Config.Framework must be auto, qb-core, esx or qbox.'
    end

    if type(Config.FrameworkPriority) ~= 'table' or #Config.FrameworkPriority == 0 then
        errors[#errors + 1] = 'Config.FrameworkPriority must contain at least one framework.'
        return
    end

    local seen = {}
    for index, framework in ipairs(Config.FrameworkPriority) do
        if framework == 'auto' or not supported[framework] then
            errors[#errors + 1] = ('Config.FrameworkPriority[%d] is unsupported.'):format(index)
        elseif seen[framework] then
            errors[#errors + 1] = ('Config.FrameworkPriority contains duplicate "%s".'):format(framework)
        end
        seen[framework] = true
        nonEmptyString(
            errors,
            ('Config.FrameworkResources.%s'):format(tostring(framework)),
            Config.FrameworkResources and Config.FrameworkResources[framework]
        )
    end
end

local function validateCrops(errors)
    if type(Config.Crops) ~= 'table' or next(Config.Crops) == nil then
        errors[#errors + 1] = 'Config.Crops must contain at least one crop.'
        return
    end

    for cropType, crop in pairs(Config.Crops) do
        local path = ('Config.Crops.%s'):format(tostring(cropType))
        if type(cropType) ~= 'string' or cropType == '' then
            errors[#errors + 1] = 'Every crop key must be a non-empty string.'
        end

        if type(crop) ~= 'table' then
            errors[#errors + 1] = path .. ' must be a table.'
        else
            for _, field in ipairs({ 'label', 'seedItem', 'productItem' }) do
                if type(crop[field]) ~= 'string' or crop[field] == '' then
                    errors[#errors + 1] = ('%s.%s must be a non-empty string.'):format(path, field)
                end
            end

            positive(errors, path .. '.growthTime', crop.growthTime, false)

            if type(crop.stages) ~= 'table' or #crop.stages == 0 then
                errors[#errors + 1] = path .. '.stages must contain at least one stage.'
            else
                local previous = -1
                for index, stage in ipairs(crop.stages) do
                    local stagePath = ('%s.stages[%d]'):format(path, index)
                    if type(stage.model) ~= 'string' or stage.model == '' then
                        errors[#errors + 1] = stagePath .. '.model must be a non-empty string.'
                    end
                    if not finite(stage.ratio) or stage.ratio < 0 or stage.ratio > 1 or stage.ratio < previous then
                        errors[#errors + 1] = stagePath .. '.ratio must be ordered within 0..1.'
                    else
                        previous = stage.ratio
                    end
                end
            end

            local water = crop.water
            if type(water) ~= 'table' then
                errors[#errors + 1] = path .. '.water must be a table.'
            else
                positive(errors, path .. '.water.decayPerHour', water.decayPerHour, true)
                if not finite(water.droughtTolerance)
                    or water.droughtTolerance < 0
                    or water.droughtTolerance > 1 then
                    errors[#errors + 1] = path .. '.water.droughtTolerance must be within 0..1.'
                end
            end

            local yield = crop.yield
            if type(yield) ~= 'table'
                or not finite(yield.min)
                or not finite(yield.max)
                or yield.min < 1
                or yield.max < yield.min then
                errors[#errors + 1] = path .. '.yield must define 1 <= min <= max.'
            end
        end
    end
end

local function validateZones(errors, warnings)
    if type(Config.Zones) ~= 'table' or next(Config.Zones) == nil then
        errors[#errors + 1] = 'Config.Zones must contain at least one zone.'
        return
    end

    local total = 0
    for zoneKey, zone in pairs(Config.Zones) do
        local path = ('Config.Zones.%s'):format(tostring(zoneKey))
        if type(zoneKey) ~= 'string' or zoneKey == '' or not zoneKey:match('^[%w_%-]+$') then
            errors[#errors + 1] = path .. ' key must contain only letters, numbers, underscores or hyphens.'
        end

        if type(zone) ~= 'table' or type(zone.label) ~= 'string' or zone.label == '' then
            errors[#errors + 1] = path .. ' must define a non-empty label.'
        else
            for _, cropType in ipairs(zone.allowedCrops or {}) do
                if not Config.Crops[cropType] then
                    errors[#errors + 1] = ('%s.allowedCrops references unknown crop "%s".')
                        :format(path, tostring(cropType))
                end
            end

            local slots = Sonar.Zones.Slots(zoneKey)
            if #slots == 0 then
                errors[#errors + 1] = path .. ' must resolve at least one slot.'
            end
            total = total + #slots

            for index, slot in ipairs(slots) do
                if not finite(slot.x) or not finite(slot.y) or not finite(slot.z) or not finite(slot.heading) then
                    errors[#errors + 1] = ('%s slot %d has invalid coordinates or heading.'):format(path, index)
                end
                for other = 1, index - 1 do
                    local candidate = slots[other]
                    local dx, dy, dz = slot.x - candidate.x, slot.y - candidate.y, slot.z - candidate.z
                    if (dx * dx + dy * dy + dz * dz) < 0.25 then
                        errors[#errors + 1] = ('%s slots %d and %d overlap.'):format(path, other, index)
                    end
                end
            end
        end
    end

    if total > 1000 then
        warnings[#warnings + 1] = ('%d target slots are configured; validate client resmon before production.'):format(total)
    end
end

local function validateSection(errors, name, fn, ...)
    local ok, err = pcall(fn, errors, ...)
    if not ok then
        errors[#errors + 1] = ('%s validation failed: %s'):format(name, tostring(err))
    end
end

function ConfigValidation.Validate()
    local errors, warnings = {}, {}

    validateSection(errors, 'Framework', validateFramework)
    validateSection(errors, 'Crop', validateCrops)
    validateSection(errors, 'Zone', validateZones, warnings)

    nonEmptyString(errors, 'Config.Admin.Ace', Config.Admin and Config.Admin.Ace)
    positive(errors, 'Config.SaveInterval', Config.SaveInterval, false)
    positive(errors, 'Config.Database.BatchChunkSize', Config.Database and Config.Database.BatchChunkSize, false)
    positive(errors, 'Config.Security.TokenBucket.capacity', Config.Security and Config.Security.TokenBucket and Config.Security.TokenBucket.capacity, false)
    positive(errors, 'Config.Security.TokenBucket.refillPerSecond', Config.Security and Config.Security.TokenBucket and Config.Security.TokenBucket.refillPerSecond, false)
    positive(errors, 'Config.Security.SubscriptionBucket.capacity', Config.Security and Config.Security.SubscriptionBucket and Config.Security.SubscriptionBucket.capacity, false)
    positive(errors, 'Config.Security.SubscriptionBucket.refillPerSecond', Config.Security and Config.Security.SubscriptionBucket and Config.Security.SubscriptionBucket.refillPerSecond, false)
    positive(errors, 'Config.Security.RateLimitLogInterval', Config.Security and Config.Security.RateLimitLogInterval, false)
    positive(errors, 'Config.Security.MaxInteractDistance', Config.Security and Config.Security.MaxInteractDistance, false)
    positive(errors, 'Config.Security.MaxSpeedMps', Config.Security and Config.Security.MaxSpeedMps, false)
    positive(errors, 'Config.Security.PositionSampleTtl', Config.Security and Config.Security.PositionSampleTtl, false)
    positive(errors, 'Config.Security.ConnectGracePeriod', Config.Security and Config.Security.ConnectGracePeriod, true)
    positive(errors, 'Config.Sync.CellRadius', Config.Sync and Config.Sync.CellRadius, true)
    positive(errors, 'Config.Sync.TickNear', Config.Sync and Config.Sync.TickNear, false)
    positive(errors, 'Config.Sync.TickFar', Config.Sync and Config.Sync.TickFar, false)
    positive(errors, 'Config.Render.Radius', Config.Render and Config.Render.Radius, false)
    positive(errors, 'Config.Render.TargetDistance', Config.Render and Config.Render.TargetDistance, false)
    positive(errors, 'Config.Render.MaxProps', Config.Render and Config.Render.MaxProps, false)

    if Config.Render and Config.Security
        and finite(Config.Render.TargetDistance)
        and finite(Config.Security.MaxInteractDistance)
        and Config.Render.TargetDistance >= Config.Security.MaxInteractDistance then
        errors[#errors + 1] = 'Config.Render.TargetDistance must be below Config.Security.MaxInteractDistance.'
    end

    local scoreWeight = Config.Quality and Config.Quality.ScoreWeight
    local careWeight = Config.Quality and Config.Quality.CareWeight
    if not finite(scoreWeight)
        or not finite(careWeight)
        or math.abs((scoreWeight + careWeight) - 1) > 0.001 then
        errors[#errors + 1] = 'Config.Quality ScoreWeight + CareWeight must equal 1.'
    end

    if type(Config.Security and Config.Security.AllowedRoutingBuckets) ~= 'table'
        or #Config.Security.AllowedRoutingBuckets == 0 then
        errors[#errors + 1] = 'Config.Security.AllowedRoutingBuckets must contain at least one bucket.'
    else
        local buckets = {}
        for index, bucket in ipairs(Config.Security.AllowedRoutingBuckets) do
            if not finite(bucket) or bucket < 0 or bucket % 1 ~= 0 then
                errors[#errors + 1] = ('Config.Security.AllowedRoutingBuckets[%d] must be a non-negative integer.')
                    :format(index)
            else
                if buckets[bucket] then
                    errors[#errors + 1] = ('Config.Security.AllowedRoutingBuckets contains duplicate %d.'):format(bucket)
                end
                buckets[bucket] = true
            end
        end
    end

    return errors, warnings
end

Sonar.ConfigValidation = ConfigValidation
