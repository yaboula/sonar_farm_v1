--[[
    sonar_farm - Validation (server)
    Multi-level authoritative checks. Every function returns a uniform
    { ok = boolean, reason? = string } so handlers can reject consistently.

    Zero-Trust rule: player position is always read from the server via
    GetEntityCoords(GetPlayerPed(source)). Client-supplied coordinates are never
    trusted for validation.

    Owns two per-player caches (cooldowns and position samples) and frees both
    on playerDropped.
]]

Validation = Validation or {}

local REJECT = Sonar.Constants.REJECT
local CROP_STATE = Sonar.Constants.CROP_STATE
local Utils = Sonar.Utils

-- [source] = { [action] = expiryMs }
local cooldowns = {}
-- [source] = { x, y, z, at = ms }
local positions = {}
-- [source] = connectTimeMs
local connectedAt = {}

local OK = { ok = true }

local function fail(reason)
    return { ok = false, reason = reason }
end

-- ---------------------------------------------------------------------------
-- Position (single source of truth for player coords)
-- ---------------------------------------------------------------------------

--- Server-side player coordinates. Returns nil when the ped is not available.
---@param source number
---@return vector3|nil
function Validation.GetPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end

    local coords = GetEntityCoords(ped)
    -- A ped that has not streamed in yet reports the world origin.
    if not coords or (math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0) then
        return nil
    end
    return coords
end

-- ---------------------------------------------------------------------------
-- Cooldowns
-- ---------------------------------------------------------------------------

--- Reject if the player is still on cooldown for `action`, otherwise arm it.
---@param source number
---@param action string
---@return table result
function Validation.Cooldown(source, action)
    local duration = Config.Cooldowns[action]
    if not duration then return OK end

    local now = GetGameTimer()
    local playerCooldowns = cooldowns[source]

    if playerCooldowns and playerCooldowns[action] and now < playerCooldowns[action] then
        return fail(REJECT.COOLDOWN)
    end

    if not playerCooldowns then
        playerCooldowns = {}
        cooldowns[source] = playerCooldowns
    end
    playerCooldowns[action] = now + duration

    return OK
end

-- ---------------------------------------------------------------------------
-- Distance
-- ---------------------------------------------------------------------------

--- Reject if the player is further than `maxDist` from `target`.
---@param source number
---@param target vector3|table
---@param maxDist? number defaults to Config.Security.MaxInteractDistance
---@return table result
function Validation.Distance(source, target, maxDist)
    local coords = Validation.GetPlayerCoords(source)
    if not coords then return fail(REJECT.TOO_FAR) end

    maxDist = maxDist or Config.Security.MaxInteractDistance
    if not Utils.IsWithin(coords, target, maxDist) then
        return fail(REJECT.TOO_FAR)
    end
    return OK
end

-- ---------------------------------------------------------------------------
-- Anti-teleport
-- ---------------------------------------------------------------------------

--- Flag implausible movement between two consecutive actions.
--- Three guards prevent false positives on legitimate players:
---   1. The first sample only seeds the cache; no speed check is applied.
---   2. Samples older than PositionSampleTtl are treated as stale (the player
---      may have changed routing bucket or entered an interior).
---   3. Players still inside ConnectGracePeriod are skipped entirely, since
---      coords are unreliable while the ped streams in.
---@param source number
---@return table result
function Validation.AntiTeleport(source)
    local coords = Validation.GetPlayerCoords(source)
    if not coords then
        -- No reliable position: nothing to compare, do not punish.
        return OK
    end

    local now = GetGameTimer()
    local previous = positions[source]

    positions[source] = { x = coords.x, y = coords.y, z = coords.z, at = now }

    -- Guard 3: connect grace period.
    local since = connectedAt[source]
    if since and (now - since) < (Config.Security.ConnectGracePeriod * 1000) then
        return OK
    end

    -- Guard 1: first sample only seeds the cache.
    if not previous then return OK end

    -- Guard 2: stale sample.
    local deltaSeconds = (now - previous.at) / 1000
    if deltaSeconds <= 0 or deltaSeconds > Config.Security.PositionSampleTtl then
        return OK
    end

    local speed = Utils.Distance(coords, previous) / deltaSeconds
    if speed > Config.Security.MaxSpeedMps then
        Logger.Exploit(('Implausible movement: %.1f m/s.'):format(speed), 'security', {
            source = source,
            identifier = Bridge.GetIdentifier(source),
            speed = Utils.Round(speed, 1),
            seconds = Utils.Round(deltaSeconds, 2),
        })
        return fail(REJECT.SUSPICIOUS_MOVEMENT)
    end

    return OK
end

-- ---------------------------------------------------------------------------
-- Zones
-- ---------------------------------------------------------------------------

--- Resolve which configured zone contains `coords`.
---@param coords vector3|table
---@return string|nil zoneKey
---@return table|nil zone
function Validation.ResolveZone(coords)
    for key, zone in pairs(Config.Zones) do
        if Utils.IsWithin(coords, zone.center, zone.radius) then
            return key, zone
        end
    end
    return nil, nil
end

--- Reject if `coords` is outside every zone, or the crop is not allowed there.
---@param coords vector3|table
---@param cropType string
---@return table result with `zoneKey` on success
function Validation.Zone(coords, cropType)
    local zoneKey, zone = Validation.ResolveZone(coords)
    if not zoneKey then
        return fail(REJECT.NOT_IN_ZONE)
    end

    local allowed = zone.allowedCrops
    if allowed and #allowed > 0 then
        local permitted = false
        for _, key in ipairs(allowed) do
            if key == cropType then
                permitted = true
                break
            end
        end
        if not permitted then
            return fail(REJECT.CROP_NOT_ALLOWED_HERE)
        end
    end

    return { ok = true, zoneKey = zoneKey }
end

-- ---------------------------------------------------------------------------
-- Inventory / crop state / ownership
-- ---------------------------------------------------------------------------

--- Reject if the player does not hold `item`.
---@param source number
---@param item string
---@param reason string reject reason to use when missing
---@param count? number
---@return table result
function Validation.HasItem(source, item, reason, count)
    if not Bridge.Inventory.HasItem(source, item, count or 1) then
        return fail(reason)
    end
    return OK
end

--- Reject if the crop id does not exist in hot state.
---@param cropId string
---@return table result with `record` on success
function Validation.Crop(cropId)
    if type(cropId) ~= 'string' then return fail(REJECT.CROP_NOT_FOUND) end

    local record = State.Get(cropId)
    if not record then return fail(REJECT.CROP_NOT_FOUND) end

    return { ok = true, record = record }
end

--- Reject if the crop is dead (nothing can be done with it but clearing).
---@param record table
---@return table result
function Validation.Alive(record)
    if record.state == CROP_STATE.DEAD then
        return fail(REJECT.CROP_DEAD)
    end
    return OK
end

--- Whether `source` may care for (water) this crop.
--- Public care lets players save a neighbour's withering crop without granting
--- any claim over the produce.
---@param source number
---@param record table
---@return table result
function Validation.CanCare(source, record)
    if Config.Farming.AllowPublicCare then return OK end

    local identifier = Bridge.GetIdentifier(source)
    if record.owner and identifier ~= record.owner then
        return fail(REJECT.NOT_OWNER)
    end
    return OK
end

--- Whether `source` may harvest this crop. When OwnerOnlyHarvest is false,
--- non-owners are allowed but flagged as theft so quality can be penalized.
---@param source number
---@param record table
---@return table result with `theft` boolean on success
function Validation.CanHarvest(source, record)
    local identifier = Bridge.GetIdentifier(source)
    local isOwner = (not record.owner) or (identifier == record.owner)

    if isOwner then
        return { ok = true, theft = false }
    end

    if Config.Farming.OwnerOnlyHarvest then
        return fail(REJECT.NOT_OWNER)
    end

    Logger.Warn(('Crop theft: %s harvested a crop owned by %s.')
        :format(tostring(identifier), tostring(record.owner)), 'farming', {
        source = source,
        cropId = record.id,
        owner = record.owner,
    })

    return { ok = true, theft = true }
end

--- Reject if the player already owns the maximum number of active crops.
---@param source number
---@return table result
function Validation.CropLimit(source)
    local limit = Config.Farming.MaxCropsPerPlayer
    if not limit or limit <= 0 then return OK end

    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return OK end

    if State.CountByOwner(identifier) >= limit then
        return fail(REJECT.CROP_LIMIT_REACHED)
    end

    return OK
end

-- ---------------------------------------------------------------------------
-- Lifecycle cleanup
-- ---------------------------------------------------------------------------

--- Free per-player caches owned by this module.
---@param source number
function Validation.Release(source)
    cooldowns[source] = nil
    positions[source] = nil
    connectedAt[source] = nil
end

AddEventHandler('playerJoining', function()
    connectedAt[source] = GetGameTimer()
end)

AddEventHandler('playerDropped', function()
    Validation.Release(source)
end)
