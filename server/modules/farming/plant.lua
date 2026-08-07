--[[
    sonar_farm - Plant action (server)
    Authoritative handler for planting. The client sends only the crop type; the
    server decides where the player actually is, whether they may plant there,
    and consumes the seed. Nothing is trusted from the client.
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

    -- Server-side position: never the coordinates the client claims.
    local coords = Validation.GetPlayerCoords(source)
    if not coords then return reject(REJECT.TOO_FAR) end

    local zone = Validation.Zone(coords, cropType)
    if not zone.ok then return reject(zone.reason) end

    local limit = Validation.CropLimit(source)
    if not limit.ok then return reject(limit.reason) end

    local seed = Validation.HasItem(source, def.seedItem, REJECT.MISSING_SEED)
    if not seed.ok then return reject(seed.reason) end

    local score = Quality.Request(source, ACTIONS.PLANT, { crop_type = cropType })

    -- Consume the seed only once every check has passed.
    if not Bridge.Inventory.RemoveItem(source, def.seedItem, 1) then
        return reject(REJECT.MISSING_SEED)
    end

    local now = os.time()
    local ped = GetPlayerPed(source)

    local cropId = State.Add({
        crop_type = cropType,
        owner = Bridge.GetIdentifier(source),
        zone = zone.zoneKey,
        pos_x = coords.x,
        pos_y = coords.y,
        pos_z = coords.z,
        heading = ped and GetEntityHeading(ped) or 0.0,
        planted_at = now,
        growth_time = def.growthTime,
        data = {
            water = 100,
            health = initialHealth(score),
            spoilage = 0,
            lastCare = now,
            careCount = 0,
            plantScore = score,
        },
    })

    Logger.Info(('Planted %s (%s) in zone %s.'):format(cropType, cropId, zone.zoneKey), 'farming', {
        source = source,
        identifier = Bridge.GetIdentifier(source),
    })

    TriggerEvent(PUBLIC.CROP_PLANTED, {
        cropId = cropId,
        cropType = cropType,
        zone = zone.zoneKey,
        owner = Bridge.GetIdentifier(source),
        source = source,
    })

    return {
        ok = true,
        data = {
            cropId = cropId,
            cropType = cropType,
            label = def.label,
            zone = zone.zoneKey,
            growthTime = def.growthTime,
        },
    }
end)
