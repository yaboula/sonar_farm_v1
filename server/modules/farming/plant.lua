--[[
    sonar_farm - Plant action (server)
    Authoritative planting into a configured slot. The client sends only the crop
    type, zone key and slot index. Coordinates come from config on the server, so
    a modified client cannot choose where a crop lands or plant outside a plot.

    Free-planting (anywhere inside a radius) was dropped: it produced overlapping
    props, messy fields and no hard capacity. A zone with 40 slots holds 40 crops,
    never 41.
]]

local ACTIONS = Sonar.Constants.ACTIONS
local CALLBACKS = Sonar.Constants.CALLBACKS
local PUBLIC = Sonar.Constants.PUBLIC_EVENTS
local REJECT = Sonar.Constants.REJECT

local function reject(reason)
    return { ok = false, reason = reason }
end

--- Initial health derived from how well the player planted. Skill matters from
--- the first action: a sloppy planting starts the crop at a disadvantage.
---@param score number 0..100
---@return number health 60..100
local function initialHealth(score)
    return Sonar.Utils.Round(60 + (40 * (Sonar.Utils.Clamp(score, 0, 100) / 100)), 1)
end

lib.callback.register(CALLBACKS.PLANT, function(source, payload)
    payload = payload or {}

    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then return reject(runtime.reason) end

    if not Security.Consume(source) then
        return reject(REJECT.RATE_LIMITED)
    end

    local cooldown = Validation.Cooldown(source, ACTIONS.PLANT)
    if not cooldown.ok then return reject(cooldown.reason) end

    local movement = Validation.AntiTeleport(source)
    if not movement.ok then return reject(movement.reason) end

    local cropType = payload.cropType
    local def = Config.Crops and Config.Crops[cropType]
    if not def then return reject(REJECT.UNKNOWN_CROP) end
    if Config.Features.Minigames and def.requiresMinigame then
        return reject(REJECT.MINIGAME_REQUIRED)
    end

    local zoneKey = payload.zone
    local slotIndex = payload.slot

    -- Lock the slot for the whole check-and-commit window. Without this, two
    -- players planting the same empty plot at once can both pass the occupancy
    -- check and create two crops before either indexes the slot.
    local lockKey = ('slot:%s:%s'):format(tostring(zoneKey), tostring(slotIndex))

    local acquired, result = Lock.With(lockKey, function()
        local slotCheck = Validation.Slot(source, zoneKey, slotIndex, cropType)
        if not slotCheck.ok then return reject(slotCheck.reason) end
        local slot = slotCheck.slot

        local fieldAccess = Fields.ResolvePlantAccess(source, cropType, zoneKey, slotIndex)
        if not fieldAccess.ok then return reject(fieldAccess.reason) end

        if fieldAccess.legacy then
            local limit = Validation.CropLimit(source)
            if not limit.ok then return reject(limit.reason) end
        end

        local seedCheck = Validation.GetSeedItem(source, def)
        if not seedCheck.ok then return reject(seedCheck.reason) end
        local seedItem = seedCheck.item

        local score = Quality.Request(source, ACTIONS.PLANT, { crop_type = cropType })

        -- Consume the seed only once every check has passed.
        if not Bridge.Inventory.RemoveItem(source, seedItem, 1) then
            return reject(REJECT.MISSING_SEED)
        end

        local now = Sonar.Time.Now()

        -- Position and heading come from the slot definition, never the player.
        local cropData = Sonar.CropClock.NewData(cropType, {
            water = 100,
            health = initialHealth(score),
            spoilage = 0,
            lastCare = now,
            careCount = 0,
            plantScore = score,
        })
        if not fieldAccess.legacy then
            cropData.fieldId = fieldAccess.field.id
            cropData.topologyRevision = fieldAccess.field.revisionId
            cropData.rowId = fieldAccess.slot.rowId
            cropData.slotId = fieldAccess.slot.id
            cropData.companyId = fieldAccess.companyId
            cropData.planId = fieldAccess.planId
            cropData.workType = fieldAccess.work.kind
            cropData.workId = fieldAccess.work.id
            cropData.plantedBy = runtime.identifier
        end
        local cropId, record = State.Add({
            crop_type = cropType,
            owner = fieldAccess.legacy and runtime.identifier or fieldAccess.companyId,
            zone = slot.zone,
            slot = slot.index,
            pos_x = slot.x,
            pos_y = slot.y,
            pos_z = slot.z,
            heading = slot.heading,
            planted_at = now,
            growth_time = def.growthTime,
            data = cropData,
        })

        if not Fields.RecordOperation(source, record, ACTIONS.PLANT, fieldAccess, { itemId = seedItem, score = score }) then
            State.Remove(record.id)
            Bridge.Inventory.AddItem(source, seedItem, 1)
            return reject(REJECT.INTERNAL_ERROR)
        end

        Sync.OnCropChanged(record)

        Logger.Info(('Planted %s (%s) in %s slot %d.'):format(cropType, cropId, slot.zone, slot.index), 'farming', {
            source = source,
            identifier = runtime.identifier,
        })

        TriggerEvent(PUBLIC.CROP_PLANTED, {
            cropId = cropId,
            cropType = cropType,
            zone = slot.zone,
            slot = slot.index,
            owner = runtime.identifier,
            source = source,
        })

        return {
            ok = true,
            data = {
                cropId = cropId,
                cropType = cropType,
                label = def.label,
                zone = slot.zone,
                slot = slot.index,
                growthTime = def.growthTime,
            },
        }
    end)

    if not acquired then
        return reject(REJECT.ALREADY_IN_PROGRESS)
    end

    return result
end)
