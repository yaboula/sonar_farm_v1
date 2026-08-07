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

lib.callback.register(CALLBACKS.WATER, function(source, payload)
    payload = payload or {}

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
        if not permission.ok then return reject(permission.reason) end

        local tool = Config.Farming.Tools.water
        local hasTool = Validation.HasItem(source, tool, REJECT.MISSING_TOOL)
        if not hasTool.ok then return reject(hasTool.reason) end

        -- Bring the crop up to date before deciding whether it needs water.
        local condition = Physiology.Apply(record)

        if condition.state == Sonar.Constants.CROP_STATE.DEAD then
            return reject(REJECT.CROP_DEAD)
        end

        if condition.water >= Config.Farming.WaterRefillThreshold then
            return reject(REJECT.ALREADY_WATERED)
        end

        local score = Quality.Request(source, ACTIONS.WATER, record)
        Physiology.Water(record, waterAmount(score))

        local updated = State.Get(record.id)
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
            },
        }
    end)

    if not acquired then
        return reject(REJECT.ALREADY_IN_PROGRESS)
    end

    return result
end)
