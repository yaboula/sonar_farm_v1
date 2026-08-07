--[[
    sonar_farm - Entity pool (client)
    Generic, content-agnostic ownership of client-side props. It knows how to
    create, track and destroy entities by key; it does not know what a crop is.
    Stage 9 machinery and future placeables reuse it as-is.

    Every entity is created non-networked (`isNetwork = false`): zero NetIDs
    consumed, zero physics sync traffic, and no impact on the server's entity
    budget. The tradeoff is that only this client sees them, which is exactly
    what we want since each client derives what to draw from its own cache.
]]

Pool = Pool or {}

-- [key] = { entity = number, model = number|string, tag = string }
local entities = {}
local count = 0

--- Load a model with a bounded wait. Returns false when the model never
--- streams in (bad name, or the asset resource is not running).
---@param model string|number
---@return boolean loaded
local function ensureModel(model)
    local hash = type(model) == 'number' and model or joaat(model)

    if not IsModelValid(hash) then
        return false
    end

    if HasModelLoaded(hash) then
        return true
    end

    RequestModel(hash)

    -- ~2s ceiling: enough for a local asset, short enough not to stall render.
    local deadline = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(10)
    end

    return HasModelLoaded(hash)
end

--- Whether a key currently has an entity.
---@param key string
---@return boolean
function Pool.Has(key)
    return entities[key] ~= nil
end

--- The entity handle for a key, if any.
---@param key string
---@return number|nil
function Pool.Get(key)
    local entry = entities[key]
    return entry and entry.entity or nil
end

--- The model currently rendered for a key, if any.
---@param key string
---@return number|string|nil
function Pool.ModelOf(key)
    local entry = entities[key]
    return entry and entry.model or nil
end

--- Number of live entities in the pool.
---@return number
function Pool.Count()
    return count
end

--- Create a non-networked object for `key`.
--- Returns nil when the model cannot be loaded, so callers can fall back.
---@param key string
---@param model string|number
---@param coords vector3|table
---@param heading number
---@param opts? table { tag?: string, freeze?: boolean }
---@return number|nil entity
function Pool.Create(key, model, coords, heading, opts)
    if entities[key] then
        return entities[key].entity
    end

    if not ensureModel(model) then
        return nil
    end

    opts = opts or {}
    local hash = type(model) == 'number' and model or joaat(model)

    local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    if not entity or entity == 0 then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetEntityHeading(entity, heading or 0.0)
    -- Static scenery: no physics, no collision cost, cannot be pushed around.
    FreezeEntityPosition(entity, opts.freeze ~= false)
    SetEntityCollision(entity, false, false)
    SetEntityAsMissionEntity(entity, false, true)

    SetModelAsNoLongerNeeded(hash)

    entities[key] = { entity = entity, model = model, tag = opts.tag }
    count = count + 1

    return entity
end

--- Destroy the entity for `key`, if any.
---@param key string
---@return boolean removed
function Pool.Destroy(key)
    local entry = entities[key]
    if not entry then return false end

    if DoesEntityExist(entry.entity) then
        DeleteEntity(entry.entity)
    end

    entities[key] = nil
    count = count - 1
    return true
end

--- Destroy every entity, optionally limited to one tag.
---@param tag? string
---@return number destroyed
function Pool.Clear(tag)
    local removed = 0
    for key, entry in pairs(entities) do
        if not tag or entry.tag == tag then
            if DoesEntityExist(entry.entity) then
                DeleteEntity(entry.entity)
            end
            entities[key] = nil
            count = count - 1
            removed = removed + 1
        end
    end
    return removed
end

--- Iterate live keys. Returns a snapshot array so callers may destroy while
--- looping without invalidating the iteration.
---@return string[]
function Pool.Keys()
    local keys = {}
    for key in pairs(entities) do
        keys[#keys + 1] = key
    end
    return keys
end

-- Orphaned props are the classic dev-loop annoyance: without this, every
-- `restart sonar_farm` leaves props nobody can remove until the player reconnects.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Pool.Clear()
end)
