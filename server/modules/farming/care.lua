--[[
    sonar_farm - Care action (server)
    Authoritative watering. Public care is allowed by default so a player can
    save a neighbour's withering crop; that grants no claim over the produce
    (see harvest.lua and Config.Farming.OwnerOnlyHarvest).
]]

local ACTIONS = Sonar.Constants.ACTIONS
local CALLBACKS = Sonar.Constants.CALLBACKS
local PUBLIC = Sonar.Constants.PUBLIC_EVENTS
local REJECT = Sonar.Constants.REJECT

local function reject(reason)
    return { ok = false, reason = reason }
end

--- Water restored based on how well the player performed the action.
---@param score number 0..100
---@return number amount 60..100
local function waterAmount(score)
    return 60 + (40 * (Sonar.Utils.Clamp(score, 0, 100) / 100))
end

lib.callback.register(CALLBACKS.CARE_OPTIONS, function(source, payload)
    payload = payload or {}
    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then return reject(runtime.reason) end
    local crop = Validation.Crop(payload.cropId)
    if not crop.ok then return reject(crop.reason) end
    local record = crop.record
    local distance = Validation.Distance(source, vec3(record.pos_x, record.pos_y, record.pos_z))
    if not distance.ok then return reject(distance.reason) end
    local permission = Validation.CanCare(source, record)
    local action = payload.action
    if action ~= ACTIONS.WATER and action ~= ACTIONS.FERTILIZE
        and action ~= ACTIONS.WEED and action ~= ACTIONS.TREAT_PEST then
        return reject(REJECT.INVALID_ITEM)
    end
    local fieldAccess = Fields.ResolveCropAccess(source, record, action)
    if not fieldAccess.ok then return reject(fieldAccess.reason) end
    if fieldAccess.legacy and not permission.ok then return reject(permission.reason) end
    if action ~= ACTIONS.WATER then
        local conditionName = action == ACTIONS.FERTILIZE and 'nutrients'
            or action == ACTIONS.WEED and 'weeds' or 'pests'
        if not Sonar.Conditions.IsEnabled(record, conditionName) then
            return reject(REJECT.CONDITION_DISABLED)
        end
    end
    return { ok = true, data = { options = Items.ListForAction(source, action, record) } }
end)

lib.callback.register(CALLBACKS.WATER, function(source, payload)
    payload = payload or {}

    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then return reject(runtime.reason) end

    if not Security.Consume(source) then
        return reject(REJECT.RATE_LIMITED)
    end

    local cooldown = Validation.Cooldown(source, ACTIONS.WATER)
    if not cooldown.ok then return reject(cooldown.reason) end

    local movement = Validation.AntiTeleport(source)
    if not movement.ok then return reject(movement.reason) end

    local crop = Validation.Crop(payload.cropId)
    if not crop.ok then return reject(crop.reason) end
    local record = crop.record

    local acquired, result = Lock.With(record.id, function()
        local distance = Validation.Distance(source, vec3(record.pos_x, record.pos_y, record.pos_z))
        if not distance.ok then return reject(distance.reason) end

        local permission = Validation.CanCare(source, record)
        local fieldAccess = Fields.ResolveCropAccess(source, record, ACTIONS.WATER)
        if not fieldAccess.ok then return reject(fieldAccess.reason) end
        if fieldAccess.legacy and not permission.ok then return reject(permission.reason) end

        -- Bring the crop up to date before deciding whether it needs water.
        local condition = Physiology.Apply(record)

        if condition.state == Sonar.Constants.CROP_STATE.DEAD then
            return reject(REJECT.CROP_DEAD)
        end

        if condition.water >= Config.Farming.WaterRefillThreshold then
            return reject(REJECT.ALREADY_WATERED)
        end

        local selected, itemReason = Items.Resolve(source, ACTIONS.WATER, payload.itemId)
        if not selected then return reject(itemReason) end
        local consumed, broken = Items.Consume(source, selected)
        if not consumed then return reject(REJECT.MISSING_TOOL) end

        local score = Quality.Request(source, ACTIONS.WATER, record)
        local waterEff = {
            amount = (selected.effect.amount or 100) * (waterAmount(score) / 100),
            protectionHours = selected.effect.protectionHours or 0,
            protectionCycleRatio = selected.effect.protectionCycleRatio or 0,
            protectionStrength = selected.effect.protectionStrength or 0,
        }
        Physiology.Water(record, waterEff, selected.definition)
        Items.RecordCompanyUse(source, selected, ACTIONS.WATER, broken)

        local updated = State.Get(record.id)
        Fields.RecordOperation(source, record, ACTIONS.WATER, fieldAccess,
            { itemId = selected.definition.id, score = score, toolBroken = broken,
                water = updated and updated.data.water or condition.water })

        Sync.OnCropChanged(updated or record)

        TriggerEvent(PUBLIC.CROP_WATERED, {
            cropId = record.id,
            cropType = record.crop_type,
            owner = record.owner,
            source = source,
        })

        return {
            ok = true,
            data = {
                cropId = record.id,
                cropType = record.crop_type,
                water = updated and updated.data.water or condition.water,
                health = condition.health,
                state = condition.state,
                itemId = selected.definition.id,
                toolBroken = broken,
            },
        }
    end)

    if not acquired then
        return reject(REJECT.ALREADY_IN_PROGRESS)
    end

    return result
end)
