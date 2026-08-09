--[[
    sonar_farm - Advanced cultivation actions (server authoritative)

    Fertilize, weed and pest treatment share the same hardened action pipeline
    as watering. The callbacks remain registered while the rollout flag is off,
    but fail closed before touching cooldowns, inventory or crop state.
]]

local ACTIONS = Sonar.Constants.ACTIONS
local CALLBACKS = Sonar.Constants.CALLBACKS
local PUBLIC = Sonar.Constants.PUBLIC_EVENTS
local REJECT = Sonar.Constants.REJECT
local CROP_STATE = Sonar.Constants.CROP_STATE

local function reject(reason)
    return { ok = false, reason = reason }
end

local function beginAction(source, action, payload)
    if not Sonar.Conditions.IsAdvancedCareEnabled() then
        return nil, reject(REJECT.CONDITION_DISABLED)
    end
    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then return nil, reject(runtime.reason) end
    if not Security.Consume(source) then return nil, reject(REJECT.RATE_LIMITED) end
    local cooldown = Validation.Cooldown(source, action)
    if not cooldown.ok then return nil, reject(cooldown.reason) end
    local movement = Validation.AntiTeleport(source)
    if not movement.ok then return nil, reject(movement.reason) end
    local crop = Validation.Crop(payload and payload.cropId)
    if not crop.ok then return nil, reject(crop.reason) end
    return { runtime = runtime, record = crop.record }
end

local function validateLocked(source, record, conditionName)
    if not Sonar.Conditions.IsEnabled(record, conditionName) then
        return nil, reject(REJECT.CONDITION_DISABLED)
    end
    local distance = Validation.Distance(source, vec3(record.pos_x, record.pos_y, record.pos_z))
    if not distance.ok then return nil, reject(distance.reason) end
    local permission = Validation.CanCare(source, record)
    if not permission.ok then return nil, reject(permission.reason) end
    return true
end

local function firstHeld(source, names)
    for _, name in ipairs(names) do
        if Bridge.Inventory.HasItem(source, name, 1) then return name end
    end
    return nil
end

lib.callback.register(CALLBACKS.FERTILIZE, function(source, payload)
    local context, failure = beginAction(source, ACTIONS.FERTILIZE, payload or {})
    if not context then return failure end
    local record = context.record
    local acquired, result = Lock.With(record.id, function()
        local valid, invalid = validateLocked(source, record, 'nutrients')
        if not valid then return invalid end
        local item = firstHeld(source, { 'fertilizer_organic', 'fertilizer_chemical' })
        if not item then return reject(REJECT.MISSING_TOOL) end

        local condition = Physiology.Apply(record)
        if condition.state == CROP_STATE.DEAD then return reject(REJECT.CROP_DEAD) end
        local def = Config.Crops[record.crop_type]
        local ceiling = def.nutrients.overfertilizeCeiling
        if condition.nutrients >= ceiling then return reject(REJECT.NUTRIENTS_SATURATED) end

        local effect = Config.Farming.AdvancedCare.Fertilizers[item]
        if not Bridge.Inventory.RemoveItem(source, item, 1) then return reject(REJECT.MISSING_TOOL) end

        local nutrients, excess = Physiology.Fertilize(record, effect.amount, effect.burnMultiplier)
        local updated = State.Get(record.id)
        Sync.OnCropChanged(updated)
        TriggerEvent(PUBLIC.CROP_FERTILIZED, {
            cropId = record.id, cropType = record.crop_type, owner = record.owner,
            source = source, item = item, nutrients = nutrients, overfertilizeExcess = excess,
        })
        return { ok = true, data = { cropId = record.id, nutrients = nutrients, overfertilizeExcess = excess } }
    end)
    return acquired and result or reject(REJECT.ALREADY_IN_PROGRESS)
end)

lib.callback.register(CALLBACKS.WEED, function(source, payload)
    local context, failure = beginAction(source, ACTIONS.WEED, payload or {})
    if not context then return failure end
    local record = context.record
    local acquired, result = Lock.With(record.id, function()
        local valid, invalid = validateLocked(source, record, 'weeds')
        if not valid then return invalid end
        local cfg = Config.Farming.AdvancedCare
        local tool = Config.Farming.Tools.weed
        if not Validation.HasItem(source, tool, REJECT.MISSING_TOOL).ok then return reject(REJECT.MISSING_TOOL) end

        local condition = Physiology.Apply(record)
        if condition.state == CROP_STATE.DEAD then return reject(REJECT.CROP_DEAD) end
        if condition.weedCover < cfg.MinimumWeedCover then return reject(REJECT.NO_WEEDS_DETECTED) end

        local weedCover = Physiology.Weed(record, cfg.WeedRemoval)
        Sync.OnCropChanged(State.Get(record.id))
        TriggerEvent(PUBLIC.CROP_WEEDED, {
            cropId = record.id, cropType = record.crop_type, owner = record.owner,
            source = source, weedCover = weedCover,
        })
        return { ok = true, data = { cropId = record.id, weedCover = weedCover } }
    end)
    return acquired and result or reject(REJECT.ALREADY_IN_PROGRESS)
end)

lib.callback.register(CALLBACKS.TREAT_PEST, function(source, payload)
    local context, failure = beginAction(source, ACTIONS.TREAT_PEST, payload or {})
    if not context then return failure end
    local record = context.record
    local acquired, result = Lock.With(record.id, function()
        local valid, invalid = validateLocked(source, record, 'pests')
        if not valid then return invalid end
        local cfg = Config.Farming.AdvancedCare
        local item = firstHeld(source, { 'pest_spray_organic', 'pest_spray_chemical' })
        if not item then return reject(REJECT.MISSING_TOOL) end

        local condition = Physiology.Apply(record)
        if condition.state == CROP_STATE.DEAD then return reject(REJECT.CROP_DEAD) end
        if condition.pestPressure < cfg.MinimumPestPressure then return reject(REJECT.NO_PEST_DETECTED) end

        local effect = cfg.PestTreatments[item]
        if not Bridge.Inventory.RemoveItem(source, item, 1) then return reject(REJECT.MISSING_TOOL) end

        local pestPressure = Physiology.TreatPests(record, effect.reduction)
        Sync.OnCropChanged(State.Get(record.id))
        TriggerEvent(PUBLIC.CROP_TREATED, {
            cropId = record.id, cropType = record.crop_type, owner = record.owner,
            source = source, item = item, pestPressure = pestPressure,
        })
        return { ok = true, data = { cropId = record.id, pestPressure = pestPressure } }
    end)
    return acquired and result or reject(REJECT.ALREADY_IN_PROGRESS)
end)
