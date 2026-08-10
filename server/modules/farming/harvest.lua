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

    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then return reject(runtime.reason) end

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
        local permission = Validation.CanHarvest(source, record)
        local fieldAccess = Fields.ResolveCropAccess(source, record, ACTIONS.HARVEST)
        if not fieldAccess.ok then return reject(fieldAccess.reason) end
        if fieldAccess.legacy and not permission.ok then return reject(permission.reason) end
        if not fieldAccess.legacy then permission = { ok = true, theft = false } end

        -- Clearing a dead Company crop is still physical Field work and must
        -- pass the same authoritative Harvest scope as a productive harvest.
        if condition.state == CROP_STATE.DEAD then
            State.Remove(record.id)
            Sync.OnCropRemoved(record.id, record.cell)
            Fields.RecordOperation(source, record, ACTIONS.HARVEST, fieldAccess,
                { deadCropCleared = true, requirementVerifiedOverride = false })
            return reject(REJECT.CROP_DEAD)
        end

        if condition.progress < 1 then return reject(REJECT.CROP_NOT_MATURE) end

        local advanced = Sonar.Conditions.IsAdvancedCareEnabled()
        local score = Quality.Request(source, ACTIONS.HARVEST, record)
        local plantingQuality = record.data and (record.data.plantingQuality
            or (advanced and record.data.plantScore))
        local quality = Quality.Resolve(score, condition, {
            theft = permission.theft,
            plantingQuality = plantingQuality,
            record = record,
        })
        local productionScore = Quality.ResolveProduction(record, condition, quality)
        local defect = Quality.DominantDefect(record, condition)
        local units = Quality.Yield(record, productionScore)
        local metadata = Quality.Metadata(record, quality, productionScore, defect)

        if not Bridge.Inventory.CanCarry(source, def.productItem, units) then
            return reject(REJECT.INVENTORY_FULL)
        end

        local prepared, prepareReason = Fields.PrepareHarvestCargo(source, record, units, metadata, fieldAccess)
        if prepareReason then return reject(prepareReason) end
        local deliveredMetadata = prepared and prepared.metadata or metadata

        -- Deliver first, remove second: a failed delivery must not destroy the crop.
        if not Bridge.Inventory.AddItem(source, def.productItem, units, deliveredMetadata) then
            Fields.CancelHarvestCargo(prepared)
            return reject(REJECT.INVENTORY_FULL)
        end

        State.Remove(record.id)
        Sync.OnCropRemoved(record.id, record.cell)
        Fields.FinalizeHarvestCargo(prepared)
        Fields.RecordOperation(source, record, ACTIONS.HARVEST, fieldAccess,
            { itemId = def.productItem, units = units, quality = quality, production = productionScore,
                cargoId = prepared and prepared.cargoId or nil })

        Logger.Info(('Harvested %s x%d (quality %.1f, %s).')
            :format(record.crop_type, units, quality, metadata.tier), 'farming', {
            source = source,
            identifier = runtime.identifier,
            cropId = record.id,
            theft = permission.theft,
        })

        TriggerEvent(PUBLIC.CROP_HARVESTED, {
            cropId = record.id,
            cropType = record.crop_type,
            owner = record.owner,
            source = source,
            quality = quality,
            productionScore = advanced and productionScore or nil,
            defect = advanced and defect or nil,
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
                productionScore = advanced and productionScore or nil,
                defect = advanced and defect or nil,
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
