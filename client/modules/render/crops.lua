--[[
    sonar_farm - Crop rendering (client)
    Owns the local crop cache and decides what is drawn. Growth and condition are
    NOT streamed from the server: they are derived here with the shared formulas
    (shared/growth.lua, shared/physiology.lua), so a field full of growing crops
    generates no network traffic at all while it grows.

    The client can only mispredict what it *draws* and which target options it
    offers. Every action is still decided by the server, and a rejection triggers
    a resync (see client/modules/interaction/actions.lua).
]]

Crops = Crops or {}

local POOL_TAG = 'crop'
local Utils = Sonar.Utils

-- [cropId] = record (shaped like a server state record so the shared evaluators
-- can consume it unchanged)
local cache = {}
-- [ "zone:slot" ] = cropId  — occupancy for empty-slot targeting
local occupancy = {}
-- Models already reported as missing, so the warning is logged once each.
local reportedModels = {}

---@param zone string|nil
---@param slot number|nil
---@return string|nil
local function occupancyKey(zone, slot)
    if not zone or not slot then return nil end
    return ('%s:%d'):format(zone, slot)
end

--- Convert a sync payload into the record shape the shared evaluators expect.
---@param payload table
---@return table record
local function toRecord(payload)
    return {
        id = payload.id,
        crop_type = payload.cropType,
        zone = payload.zone,
        slot = payload.slot and tonumber(payload.slot) or nil,
        cell = payload.cell,
        pos_x = payload.x,
        pos_y = payload.y,
        pos_z = payload.z,
        heading = payload.heading or 0.0,
        planted_at = payload.plantedAt,
        growth_time = payload.growthTime,
        isMine = payload.isMine and true or false,
        data = {
            water = payload.water,
            health = payload.health,
            lastCare = payload.lastCare,
        },
    }
end

local function indexOccupancy(record)
    local key = occupancyKey(record.zone, record.slot)
    if key then
        occupancy[key] = record.id
    end
end

local function clearOccupancy(record)
    local key = occupancyKey(record.zone, record.slot)
    if key and occupancy[key] == record.id then
        occupancy[key] = nil
    end
end

--- Insert or update one crop.
---@param payload table
function Crops.Upsert(payload)
    if not payload or not payload.id then return end

    local previous = cache[payload.id]
    if previous then
        clearOccupancy(previous)
    end

    local record = toRecord(payload)
    cache[payload.id] = record
    indexOccupancy(record)
end

--- Drop one crop and its prop.
---@param cropId string
function Crops.Remove(cropId)
    if not cropId then return end

    local record = cache[cropId]
    if record then
        clearOccupancy(record)
    end

    cache[cropId] = nil
    Crops.Despawn(cropId)
end

--- Replace the whole cache with a subscription snapshot. The snapshot is the
--- complete truth for the subscribed cells, so anything missing from it is gone
--- (harvested by someone else, or now out of range).
---@param payloads table[]
function Crops.ReplaceAll(payloads)
    cache = {}
    occupancy = {}

    for _, payload in ipairs(payloads or {}) do
        if payload.id then
            local record = toRecord(payload)
            cache[payload.id] = record
            indexOccupancy(record)
        end
    end

    -- Drop props whose crop is no longer in the cache.
    for _, key in ipairs(Pool.Keys(POOL_TAG)) do
        if not cache[key] then
            Crops.Despawn(key)
        end
    end
end

--- Whether a configured slot is occupied (from the local cache).
---@param zoneKey string
---@param slotIndex number
---@return boolean
function Crops.IsSlotOccupied(zoneKey, slotIndex)
    local key = occupancyKey(zoneKey, slotIndex)
    return key ~= nil and occupancy[key] ~= nil
end

--- Crop id occupying a slot, if any.
---@param zoneKey string
---@param slotIndex number
---@return string|nil
function Crops.SlotOccupant(zoneKey, slotIndex)
    local key = occupancyKey(zoneKey, slotIndex)
    return key and occupancy[key] or nil
end

--- One cached crop record.
---@param cropId string
---@return table|nil
function Crops.Get(cropId)
    return cache[cropId]
end

--- Number of cached crops.
---@return number
function Crops.Count()
    return Utils.TableSize(cache)
end

--- Current condition of a cached crop, derived locally.
---@param cropId string
---@return table|nil condition
function Crops.Condition(cropId)
    local record = cache[cropId]
    if not record then return nil end
    return Physiology.Evaluate(record)
end

--- Closest cached crop to a position, within `radius`.
---@param coords vector3
---@param radius? number
---@return string|nil cropId
---@return number|nil distance
function Crops.Closest(coords, radius)
    radius = radius or Config.Render.Radius

    local bestId, bestDist
    for id, record in pairs(cache) do
        local dist = Utils.Distance(coords, { x = record.pos_x, y = record.pos_y, z = record.pos_z })
        if dist <= radius and (not bestDist or dist < bestDist) then
            bestId, bestDist = id, dist
        end
    end
    return bestId, bestDist
end

-- ---------------------------------------------------------------------------
-- Visual resolution
-- ---------------------------------------------------------------------------

--- Model for a crop at a given growth stage.
---@param record table
---@param stageIndex number
---@return string model
local function stageModel(record, stageIndex)
    local def = Config.Crops and Config.Crops[record.crop_type]
    local stages = def and def.stages

    if not stages or #stages == 0 then
        return Config.Render.FallbackModel
    end

    local stage = stages[stageIndex] or stages[#stages]
    return (stage and stage.model) or Config.Render.FallbackModel
end

--- Stable hash of a crop id. Used for visual variation that every client agrees
--- on: with math.random two players would see the same plant rotated differently.
---@param id string
---@return number
local function hashOf(id)
    local hash = 5381
    for i = 1, #id do
        hash = (hash * 33 + id:byte(i)) % 4294967296
    end
    return hash
end

--- Heading for a crop, with deterministic variation so fields do not look like
--- a cloned grid.
---@param record table
---@return number
local function headingFor(record)
    if not Config.Render.Variation then
        return record.heading or 0.0
    end
    return (hashOf(record.id) % 360) + 0.0
end

--- Placement coordinates, snapped to the ground when enabled. The stored z is
--- the planter's foot position, which floats or sinks on any slope.
---@param record table
---@return vector3
local function placementFor(record)
    local x, y, z = record.pos_x, record.pos_y, record.pos_z

    if Config.Render.GroundSnap then
        local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
        if found and math.abs(groundZ - z) < 3.0 then
            z = groundZ
        end
    end

    return vec3(x, y, z)
end

-- ---------------------------------------------------------------------------
-- Spawn / despawn
-- ---------------------------------------------------------------------------

--- Create (or re-create on stage change) the prop for a crop.
---@param cropId string
---@param stageIndex number
local function spawn(cropId, stageIndex)
    local record = cache[cropId]
    if not record then return end

    local model = stageModel(record, stageIndex)

    -- Same model already rendered: nothing to do.
    if Pool.ModelOf(cropId) == model then return end

    -- Stage changed: destroy and re-create. There is no clean model swap on a
    -- live entity, and a stage changes at most a handful of times per crop.
    if Pool.Has(cropId) then
        Crops.Despawn(cropId)
    end

    local coords = placementFor(record)
    local entity = Pool.Create(cropId, model, coords, headingFor(record), { tag = POOL_TAG })

    if not entity and model ~= Config.Render.FallbackModel then
        if not reportedModels[model] then
            reportedModels[model] = true
            Bridge.Log('warn', ('Crop model "%s" could not be loaded. Is the plant prop pack running? Falling back to "%s".')
                :format(model, Config.Render.FallbackModel))
        end
        entity = Pool.Create(cropId, Config.Render.FallbackModel, coords, headingFor(record), { tag = POOL_TAG })
    end

    if entity then
        Target.Attach(entity, cropId)
    end
end

--- Destroy the prop for a crop (the cache entry is untouched).
---@param cropId string
function Crops.Despawn(cropId)
    local entity = Pool.Get(cropId)
    if entity then
        Target.Detach(entity)
    end
    Pool.Destroy(cropId)
end

-- ---------------------------------------------------------------------------
-- Refresh (called from the sync tick, never per frame)
-- ---------------------------------------------------------------------------

--- Reconcile rendered props with what should be visible from `coords`.
--- Renders the closest crops within Config.Render.Radius, up to MaxProps, and
--- removes everything else.
---@param coords vector3
---@return number rendered
function Crops.Refresh(coords)
    local radius = Config.Render.Radius

    local candidates = {}
    for id, record in pairs(cache) do
        local dist = Utils.Distance(coords, { x = record.pos_x, y = record.pos_y, z = record.pos_z })
        if dist <= radius then
            candidates[#candidates + 1] = { id = id, dist = dist }
        end
    end

    -- Closest first, so the prop budget is spent on what the player can see.
    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local max = Config.Render.MaxProps
    local wanted = {}

    for i = 1, math.min(#candidates, max) do
        local id = candidates[i].id
        wanted[id] = true

        local condition = Crops.Condition(id)
        spawn(id, condition and condition.stageIndex or 1)
    end

    -- Anything rendered but no longer wanted (out of range, over budget, gone).
    for _, key in ipairs(Pool.Keys(POOL_TAG)) do
        if not wanted[key] then
            Crops.Despawn(key)
        end
    end

    return Utils.TableSize(wanted)
end

--- Destroy every crop prop, keeping the cache.
function Crops.DespawnAll()
    for _, key in ipairs(Pool.Keys(POOL_TAG)) do
        Crops.Despawn(key)
    end
end

--- Wipe cache and props (used on resubscription failure and on stop).
function Crops.Reset()
    Crops.DespawnAll()
    cache = {}
    occupancy = {}
end

-- ---------------------------------------------------------------------------
-- Boot model check
-- ---------------------------------------------------------------------------

-- Informational, and deliberately delayed: the plant prop pack is its own
-- resource and may still be starting. A wrong model name is otherwise invisible
-- (CreateObject just fails and nothing appears), which is a miserable thing to
-- debug. Runs outside debug mode too, because a missing prop pack is a production
-- problem, not a developer curiosity. There is a runtime fallback either way.
CreateThread(function()
    Wait(5000)

    local missing = {}
    for cropType, def in pairs(Config.Crops or {}) do
        for _, stage in ipairs(def.stages or {}) do
            if stage.model and not IsModelValid(joaat(stage.model)) then
                missing[#missing + 1] = ('%s (%s)'):format(stage.model, cropType)
            end
        end
    end

    if #missing > 0 then
        Bridge.Log('warn', ('Missing crop models: %s. They will render as "%s".')
            :format(table.concat(missing, ', '), Config.Render.FallbackModel))
    elseif Config.Debug then
        Bridge.Log('info', 'All configured crop models are valid.')
    end

    -- If the fallback itself is invalid, nothing would render at all and the
    -- cause would be entirely silent.
    if not IsModelValid(joaat(Config.Render.FallbackModel)) then
        Bridge.Log('warn', ('Config.Render.FallbackModel "%s" is not a valid model. Crops with missing models will not render at all.')
            :format(Config.Render.FallbackModel))
    end
end)
