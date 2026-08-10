--[[
    sonar_farm - Authoritative planting minigame lifecycle

    Sessions reserve a real planting slot in hot state before the NUI opens.
    Checkpoints are ordered, bounded and rescored on the server. The seedling is
    removed exactly once at final commit; abandoned sessions never create a
    planted crop and can be resumed for a limited period.
]]

Minigames = Minigames or {}

local CALLBACKS = Sonar.Constants.CALLBACKS
local CROP_STATE = Sonar.Constants.CROP_STATE
local PUBLIC = Sonar.Constants.PUBLIC_EVENTS
local REJECT = Sonar.Constants.REJECT
local STEPS = { 'prepare', 'place', 'cover', 'water' }

local sessions = {}
local activeBySource = {}

local function reject(reason, detail)
    return { ok = false, reason = reason, detail = detail }
end

local function nowMs()
    return GetGameTimer()
end

local function plantingConfig(cropType)
    return Config.Minigames
        and Config.Minigames.Plant
        and Config.Minigames.Plant[cropType]
end

local function publicConfig(cfg)
    return {
        contractVersion = cfg.contractVersion,
        maxSamplesPerStep = cfg.maxSamplesPerStep,
        sampleIntervalMs = cfg.sampleIntervalMs,
        maximumStepDurationMs = cfg.maximumStepDurationMs,
        minimumStepDurationMs = cfg.minimumStepDurationMs,
    }
end

local function encodeSize(value)
    local ok, encoded = pcall(json.encode, value)
    if not ok or type(encoded) ~= 'string' then return math.huge end
    return #encoded
end

local function sessionPayload(session)
    local step = STEPS[session.nextStep]
    return {
        sessionId = session.id,
        cropId = session.cropId,
        cropType = session.cropType,
        zone = session.zone,
        slot = session.slot,
        nextStep = step,
        completed = session.steps,
        interruptions = session.interruptions,
        contract = publicConfig(session.config),
    }
end

local function persistSession(session, state)
    local record = State.Get(session.cropId)
    if not record then return false end

    local data = record.data or {}
    data.planting = {
        contractVersion = session.config.contractVersion,
        nextStep = session.nextStep,
        steps = session.steps,
        interruptions = session.interruptions,
        updatedAt = Sonar.Time.Now(),
    }

    return State.Update(record.id, {
        state = state or CROP_STATE.PLANTING,
        data = data,
    }) == true
end

local function releaseSession(session)
    if not session then return end
    sessions[session.id] = nil
    if activeBySource[session.source] == session.id then
        activeBySource[session.source] = nil
    end
end

local function expireSession(session, reason)
    if not session then return end
    session.interruptions = math.min(
        (session.interruptions or 0) + 1,
        math.ceil((session.config.maxInterruptionPenalty or 20) / math.max(session.config.interruptionPenalty or 1, 1))
    )
    persistSession(session, CROP_STATE.PLANTING_FAILED)
    releaseSession(session)
    Logger.Info(('Planting session %s interrupted (%s).'):format(session.id, reason or 'unknown'), 'minigame', {
        source = session.source,
        cropId = session.cropId,
        step = STEPS[session.nextStep],
    })
end

local function ownedSession(source, sessionId)
    if type(sessionId) ~= 'string' then return nil, REJECT.MINIGAME_SESSION_NOT_FOUND end
    local session = sessions[sessionId]
    if not session or session.source ~= source then
        return nil, REJECT.MINIGAME_SESSION_NOT_FOUND
    end
    if nowMs() > session.expiresAt then
        expireSession(session, 'expired')
        return nil, REJECT.MINIGAME_SESSION_EXPIRED
    end
    return session
end

local function guardSource(source)
    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then return nil, runtime.reason end
    if not Config.Features.Minigames then return nil, REJECT.MINIGAME_DISABLED end
    if not Security.Consume(source, 1, 'minigame') then return nil, REJECT.RATE_LIMITED end
    return runtime
end

local function slotKey(zone, slot)
    return ('slot:%s:%s'):format(tostring(zone), tostring(slot))
end

local function createReservation(source, runtime, cropType, zoneKey, slotIndex, cfg)
    local slot = Validation.Slot(source, zoneKey, slotIndex, cropType)
    if not slot.ok then return nil, slot.reason end

    local fieldAccess = Fields.ResolvePlantAccess(source, cropType, zoneKey, slotIndex)
    if not fieldAccess.ok then return nil, fieldAccess.reason end
    if fieldAccess.legacy then
        local limit = Validation.CropLimit(source)
        if not limit.ok then return nil, limit.reason end
    end

    local def = Config.Crops and Config.Crops[cropType]
    if not def then return nil, REJECT.UNKNOWN_CROP end

    local seedCheck = Validation.GetSeedItem(source, def)
    if not seedCheck.ok then return nil, seedCheck.reason end

    local acquired, result = Lock.With(slotKey(zoneKey, slotIndex), function()
        local recheck = Validation.Slot(source, zoneKey, slotIndex, cropType)
        if not recheck.ok then return { reason = recheck.reason } end

        local cropData = Sonar.CropClock.NewData(cropType, {
            water = 0, health = 100, spoilage = 0, lastCare = Sonar.Time.Now(),
        })
        if not fieldAccess.legacy then
            cropData.fieldId, cropData.topologyRevision = fieldAccess.field.id, fieldAccess.field.revisionId
            cropData.rowId, cropData.slotId = fieldAccess.slot.rowId, fieldAccess.slot.id
            cropData.companyId, cropData.planId = fieldAccess.companyId, fieldAccess.planId
            cropData.workType, cropData.workId, cropData.plantedBy = fieldAccess.work.kind, fieldAccess.work.id, runtime.identifier
        end
        local cropId, record = State.Add({
            crop_type = cropType,
            owner = fieldAccess.legacy and runtime.identifier or fieldAccess.companyId,
            zone = zoneKey,
            slot = slotIndex,
            pos_x = recheck.slot.x,
            pos_y = recheck.slot.y,
            pos_z = recheck.slot.z,
            heading = recheck.slot.heading or 0.0,
            planted_at = Sonar.Time.Now(),
            growth_time = def.growthTime,
            state = CROP_STATE.PLANTING,
            data = cropData,
        })
        if not cropId then return { reason = REJECT.INTERNAL_ERROR } end
        return { record = record }
    end)

    if not acquired then return nil, REJECT.ALREADY_IN_PROGRESS end
    if result.reason then return nil, result.reason end

    local session = {
        id = Sonar.Utils.Uuid(),
        source = source,
        owner = runtime.identifier,
        cropId = result.record.id,
        cropType = cropType,
        zone = zoneKey,
        slot = slotIndex,
        steps = {},
        nextStep = 1,
        interruptions = 0,
        config = cfg,
        createdAt = nowMs(),
        expiresAt = nowMs() + cfg.sessionTtl * 1000,
    }
    sessions[session.id] = session
    activeBySource[source] = session.id
    persistSession(session)
    Sync.OnCropChanged(State.Get(session.cropId))
    return session
end

local function restoreSession(source, runtime, record, cfg)
    local data = record.data or {}
    if record.owner ~= runtime.identifier and data.plantedBy ~= runtime.identifier then return nil, REJECT.NOT_OWNER end
    if record.state ~= CROP_STATE.PLANTING and record.state ~= CROP_STATE.PLANTING_FAILED then
        return nil, REJECT.PLANTING_NOT_FAILED
    end

    local saved = record.data and record.data.planting or {}
    local nextStep = tonumber(saved.nextStep) or 1
    if nextStep < 1 or nextStep > #STEPS then nextStep = 1 end

    local session = {
        id = Sonar.Utils.Uuid(),
        source = source,
        owner = runtime.identifier,
        cropId = record.id,
        cropType = record.crop_type,
        zone = record.zone,
        slot = record.slot,
        steps = type(saved.steps) == 'table' and saved.steps or {},
        nextStep = nextStep,
        interruptions = tonumber(saved.interruptions) or 0,
        config = cfg,
        createdAt = nowMs(),
        expiresAt = nowMs() + cfg.sessionTtl * 1000,
    }
    sessions[session.id] = session
    activeBySource[source] = session.id
    persistSession(session)
    Sync.OnCropChanged(State.Get(session.cropId))
    return session
end

local function commit(session)
    local record = State.Get(session.cropId)
    if not record then return nil, REJECT.CROP_NOT_FOUND end

    local def = Config.Crops and Config.Crops[record.crop_type]
    if not def then return nil, REJECT.UNKNOWN_CROP end
    local seedCheck = Validation.GetSeedItem(session.source, def)
    if not seedCheck.ok then return nil, seedCheck.reason end
    local seedItem = seedCheck.item
    local fieldAccess = Fields.ResolveCropAccess(session.source, record, Sonar.Constants.ACTIONS.PLANT)
    if not fieldAccess.ok then return nil, fieldAccess.reason end

    local penalty = math.min(
        session.interruptions * (session.config.interruptionPenalty or 0),
        session.config.maxInterruptionPenalty or 20
    )
    local final, reason = TomatoPlantScoring.Finalize(session.steps, session.config, penalty)
    if not final then return nil, reason end

    -- This is the only seed mutation in the lifecycle. The session is released
    -- immediately after success, so retries cannot consume a second seedling.
    if not Bridge.Inventory.RemoveItem(session.source, seedItem, 1) then
        return nil, REJECT.MISSING_SEED
    end

    local now = Sonar.Time.Now()
    local hydration = session.steps.water and session.steps.water.score or 0
    local initialWater = session.config.initialWater or { min = 55, max = 100 }
    local water = initialWater.min + (initialWater.max - initialWater.min) * hydration / 100
    local data = record.data or {}
    data.water = Sonar.Utils.Round(water, 1)
    data.health = 100
    data.spoilage = 0
    data.lastCare = now
    data.plantingQuality = final.score
    data.planting = {
        contractVersion = session.config.contractVersion,
        outcomes = final.outcomes,
        score = final.score,
        band = final.band,
        interruptions = session.interruptions,
        completedAt = now,
    }

    local updatedOk = State.Update(record.id, {
        planted_at = now,
        state = CROP_STATE.PLANTED,
        data = data,
    })
    if not updatedOk then
        if not Bridge.Inventory.AddItem(session.source, seedItem, 1) then
            Logger.Warn(('Could not refund %s after planting commit failure.'):format(seedItem), 'minigame', {
                source = session.source,
                cropId = record.id,
            })
        end
        return nil, REJECT.INTERNAL_ERROR
    end
    local updated = State.Get(record.id)
    if not Fields.RecordOperation(session.source, updated, Sonar.Constants.ACTIONS.PLANT, fieldAccess,
        { itemId = seedItem, score = final.score, minigame = true }) then
        return nil, REJECT.INTERNAL_ERROR
    end
    Sync.OnCropChanged(updated)

    TriggerEvent(PUBLIC.CROP_PLANTED, {
        cropId = updated.id,
        cropType = updated.crop_type,
        owner = updated.owner,
        source = session.source,
        zone = updated.zone,
        slot = updated.slot,
        quality = final.score,
        outcomes = final.outcomes,
    })

    Logger.Info(('Completed %s planting (quality %.1f).'):format(updated.crop_type, final.score), 'minigame', {
        source = session.source,
        identifier = session.owner,
        cropId = updated.id,
        interruptions = session.interruptions,
    })

    releaseSession(session)
    return {
        cropId = updated.id,
        cropType = updated.crop_type,
        qualityBand = final.band,
        outcomes = final.outcomes,
        water = data.water,
    }
end

lib.callback.register(CALLBACKS.MINIGAME_BEGIN, function(source, payload)
    payload = payload or {}
    local runtime, reason = guardSource(source)
    if not runtime then return reject(reason) end
    local cooldown = Validation.Cooldown(source, Sonar.Constants.ACTIONS.PLANT)
    if not cooldown.ok then return reject(cooldown.reason) end
    local movement = Validation.AntiTeleport(source)
    if not movement.ok then return reject(movement.reason) end

    local activeId = activeBySource[source]
    local active = activeId and sessions[activeId]
    if active then
        active.expiresAt = nowMs() + active.config.sessionTtl * 1000
        return { ok = true, restore = true, data = sessionPayload(active) }
    end

    local cropType = type(payload.cropType) == 'string' and payload.cropType or ''
    local cfg = plantingConfig(cropType)
    if not cfg then return reject(REJECT.MINIGAME_REQUIRED) end

    local session
    session, reason = createReservation(source, runtime, cropType, payload.zone, payload.slot, cfg)
    if not session then return reject(reason) end
    return { ok = true, restore = false, data = sessionPayload(session) }
end)

lib.callback.register(CALLBACKS.MINIGAME_CHECKPOINT, function(source, payload)
    payload = payload or {}
    local runtime, reason = guardSource(source)
    if not runtime then return reject(reason) end

    local session
    session, reason = ownedSession(source, payload.sessionId)
    if not session then return reject(reason) end

    local acquired, response = Lock.With(('minigame:%s'):format(session.id), function()
        local expected = STEPS[session.nextStep]
        if payload.step ~= expected then return reject(REJECT.MINIGAME_INVALID_STEP, expected) end
        if tostring(payload.contractVersion) ~= session.config.contractVersion then
            return reject(REJECT.MINIGAME_INVALID_TRACE, 'contract_version')
        end
        if encodeSize(payload.trace) > session.config.maxPayloadBytes then
            return reject(REJECT.MINIGAME_INVALID_TRACE, 'payload_too_large')
        end

        local record = State.Get(session.cropId)
        if not record then
            releaseSession(session)
            return reject(REJECT.CROP_NOT_FOUND)
        end
        local distance = Validation.Distance(source, vec3(record.pos_x, record.pos_y, record.pos_z))
        if not distance.ok then
            expireSession(session, distance.reason)
            return reject(distance.reason)
        end

        local result
        result, reason = TomatoPlantScoring.ScoreStep(expected, payload.trace, session.config)
        if not result then return reject(REJECT.MINIGAME_INVALID_TRACE, reason) end

        if expected == 'water' then
            local pending = {}
            for key, value in pairs(session.steps) do pending[key] = value end
            pending.water = result
            session.steps = pending
            local committed
            committed, reason = commit(session)
            if not committed then
                session.steps.water = nil
                return reject(reason)
            end
            return { ok = true, complete = true, data = committed }
        end

        -- Persist only validated metrics and score, not hundreds of raw samples.
        session.steps[expected] = {
            step = result.step,
            score = result.score,
            band = result.band,
            metrics = result.metrics,
        }
        session.nextStep = session.nextStep + 1
        session.expiresAt = nowMs() + session.config.sessionTtl * 1000
        persistSession(session)

        return {
            ok = true,
            complete = false,
            data = {
                accepted = expected,
                band = result.band,
                metrics = result.metrics,
                nextStep = STEPS[session.nextStep],
            },
        }
    end)

    if not acquired then return reject(REJECT.ALREADY_IN_PROGRESS) end
    return response
end)

lib.callback.register(CALLBACKS.MINIGAME_CANCEL, function(source, payload)
    payload = payload or {}
    local session = ownedSession(source, payload.sessionId)
    if not session then return { ok = true } end
    local acquired, response = Lock.With(('minigame:%s'):format(session.id), function()
        expireSession(session, type(payload.reason) == 'string' and payload.reason or 'cancelled')
        return { ok = true, cropId = session.cropId, resumable = true }
    end)
    return acquired and response or reject(REJECT.ALREADY_IN_PROGRESS)
end)

lib.callback.register(CALLBACKS.MINIGAME_RESUME, function(source, payload)
    payload = payload or {}
    local runtime, reason = guardSource(source)
    if not runtime then return reject(reason) end
    if activeBySource[source] then
        local active = sessions[activeBySource[source]]
        return active and { ok = true, restore = true, data = sessionPayload(active) }
            or reject(REJECT.MINIGAME_SESSION_NOT_FOUND)
    end

    local cropId = type(payload.cropId) == 'string' and payload.cropId or ''
    local record = State.Get(cropId)
    if not record then return reject(REJECT.CROP_NOT_FOUND) end
    local distance = Validation.Distance(source, vec3(record.pos_x, record.pos_y, record.pos_z))
    if not distance.ok then return reject(distance.reason) end
    local cfg = plantingConfig(record.crop_type)
    if not cfg then return reject(REJECT.MINIGAME_REQUIRED) end

    local session
    session, reason = restoreSession(source, runtime, record, cfg)
    if not session then return reject(reason) end
    return { ok = true, restore = true, data = sessionPayload(session) }
end)

lib.callback.register(CALLBACKS.MINIGAME_CLEAR_INCOMPLETE, function(source, payload)
    payload = payload or {}
    local runtime, reason = guardSource(source)
    if not runtime then return reject(reason) end

    local cropId = type(payload.cropId) == 'string' and payload.cropId or ''
    local record = State.Get(cropId)
    if not record then return { ok = true } end
    local data = record.data or {}
    if record.owner ~= runtime.identifier and data.plantedBy ~= runtime.identifier then
        return reject(REJECT.NOT_OWNER)
    end
    if record.state ~= CROP_STATE.PLANTING_FAILED then return reject(REJECT.PLANTING_NOT_FAILED) end
    local distance = Validation.Distance(source, vec3(record.pos_x, record.pos_y, record.pos_z))
    if not distance.ok then return reject(distance.reason) end

    local removed = State.Remove(record.id)
    if removed then Sync.OnCropRemoved(record.id, record.cell) end
    return { ok = removed and true or false }
end)

AddEventHandler('playerDropped', function()
    local id = activeBySource[source]
    if id then expireSession(sessions[id], 'player_dropped') end
end)

-- Coarse cleanup only; active interactions refresh their deadline on every
-- accepted checkpoint. Failed reservations are released after the resume window.
CreateThread(function()
    while true do
        Wait(30000)
        local current = nowMs()
        local expired = {}
        for _, session in pairs(sessions) do
            if current > session.expiresAt then expired[#expired + 1] = session end
        end
        for _, session in ipairs(expired) do expireSession(session, 'expired') end

        local stale = {}
        for id, record in pairs(State.crops or {}) do
            local planting = record.data and record.data.planting
            local cfg = plantingConfig(record.crop_type)
            local cutoff = Sonar.Time.Now() - (cfg and cfg.incompleteTtl or 1800)
            if (record.state == CROP_STATE.PLANTING or record.state == CROP_STATE.PLANTING_FAILED)
                and planting and tonumber(planting.updatedAt) and planting.updatedAt < cutoff then
                local hasLiveSession = false
                for _, session in pairs(sessions) do
                    if session.cropId == id then hasLiveSession = true break end
                end
                if not hasLiveSession then stale[#stale + 1] = { id = id, cell = record.cell } end
            end
        end
        for _, entry in ipairs(stale) do
            if State.Remove(entry.id) then Sync.OnCropRemoved(entry.id, entry.cell) end
        end
    end
end)

