--[[
    sonar_farm - Harvest action (server)
    Authoritative harvest. Produce is only created after the inventory is proven
    to have room, and the crop is only removed from state after the produce is
    delivered, so a full inventory can never destroy a crop.

    The in-flight lock prevents two concurrent harvests of the same crop from
    each delivering produce (duplication).
]]

local ACTIONS = Sonar.Constants.ACTIONS
local CALLBACKS = Sonar.Constants.CALLBACKS
local PUBLIC = Sonar.Constants.PUBLIC_EVENTS
local REJECT = Sonar.Constants.REJECT
local CROP_STATE = Sonar.Constants.CROP_STATE

local function reject(reason)
    return { ok = false, reason = reason }
end

lib.callback.register(CALLBACKS.HARVEST, function(source, payload)
    payload = payload or {}

    if not Security.Consume(source) then
        return reject(REJECT.RATE_LIMITED)
    end

    local cooldown = Validation.Cooldown(source, ACTIONS.HARVEST)
    if not cooldown.ok then return reject(cooldown.reason) end

    local movement = Validation.AntiTeleport(source)
    if not movement.ok then return reject(movement.reason) end

    local crop = Validation.Crop(payload.cropId)
    if not crop.ok then return reject(crop.reason) end
    local record = crop.record

    local acquired, result = Lock.With(record.id, function()
        local distance = Validation.Distance(source, vec3(record.pos_x, record.pos_y, record.pos_z))
        if not distance.ok then return reject(distance.reason) end

        local def = Config.Crops and Config.Crops[record.crop_type]
        if not def then return reject(REJECT.UNKNOWN_CROP) end

        local condition = Physiology.Apply(record)

        -- A dead crop yields nothing; clear it so the plot is usable again.
        if condition.state == CROP_STATE.DEAD then
            State.Remove(record.id)
            return reject(REJECT.CROP_DEAD)
        end

        if condition.progress < 1 then
            return reject(REJECT.CROP_NOT_MATURE)
        end

        local permission = Validation.CanHarvest(source, record)
        if not permission.ok then return reject(permission.reason) end

        local score = Quality.Request(source, ACTIONS.HARVEST, record)
        local quality = Quality.Resolve(score, condition, { theft = permission.theft })
        local units = Quality.Yield(record, quality)
        local metadata = Quality.Metadata(record, quality)

        if not Bridge.Inventory.CanCarry(source, def.productItem, units) then
            return reject(REJECT.INVENTORY_FULL)
        end

        -- Deliver first, remove second: a failed delivery must not destroy the crop.
        if not Bridge.Inventory.AddItem(source, def.productItem, units, metadata) then
            return reject(REJECT.INVENTORY_FULL)
        end

        State.Remove(record.id)

        Logger.Info(('Harvested %s x%d (quality %.1f, %s).')
            :format(record.crop_type, units, quality, metadata.tier), 'farming', {
            source = source,
            identifier = Bridge.GetIdentifier(source),
            cropId = record.id,
            theft = permission.theft,
        })

        TriggerEvent(PUBLIC.CROP_HARVESTED, {
            cropId = record.id,
            cropType = record.crop_type,
            owner = record.owner,
            source = source,
            quality = quality,
            units = units,
            theft = permission.theft,
            xp = def.xpReward,
        })

        return {
            ok = true,
            data = {
                cropId = record.id,
                cropType = record.crop_type,
                item = def.productItem,
                units = units,
                quality = quality,
                tier = metadata.tier,
                tierLabel = metadata.label,
                theft = permission.theft,
                xp = def.xpReward,
            },
        }
    end)

    if not acquired then
        return reject(REJECT.ALREADY_IN_PROGRESS)
    end

    return result
end)
