--[[
    sonar_farm - Empty planting slots (client)
    One ox_target sphere per configured EMPTY plot. When a slot is occupied the
    zone is REMOVED entirely so it never competes with the crop's entity target.
    When the crop is removed (harvest/death), the sphere is re-created.

    This is critical: ox_target cannot cleanly layer a sphere zone and a local
    entity target at the same position. The sphere must not exist while a crop
    prop is present, otherwise ox_target fires both and the player sees "Plant
    Seeds" even when looking at a fully grown plant.

    Occupancy is derived from the local crop cache (Crops.IsSlotOccupied), kept
    current by the sync layer. The reconcile step (called from the sync tick) is
    the only place that adds or removes zones, keeping lifecycle changes in one spot.
]]

Slots = Slots or {}

local POOL_TAG = 'slot'
-- [ "zone:index" ] = { zoneId = number|string|nil, propKey = string }
-- zoneId is nil when the slot is currently occupied (zone removed).
local registered = {}

---@param zoneKey string
---@param index number
---@return string
local function keyOf(zoneKey, index)
    return ('%s:%d'):format(zoneKey, index)
end

---@param zoneKey string
---@param index number
---@return string
local function propKeyOf(zoneKey, index)
    return ('slot:%s:%d'):format(zoneKey, index)
end

--- Build and register an ox_target sphere for one empty slot.
---@param slot table
---@param key string
---@return number|string|nil zoneId
local function createSphereZone(slot, key)
    local zoneKey = slot.zone
    local index   = slot.index
    local radius  = Config.Render.SlotTargetRadius or 1.2

    return Bridge.Target.AddSphereZone({
        name   = ('sonar_farm:slot:%s'):format(key),
        coords = vec3(slot.x, slot.y, slot.z),
        radius = radius,
        debug  = false,
        options = {
            {
                name     = ('sonar_farm:plant:%s'):format(key),
                label    = 'Plant seeds',
                icon     = 'fa-solid fa-seedling',
                distance = Config.Render.TargetDistance,
                onSelect = function()
                    Actions.OpenPlantMenu(zoneKey, index)
                end,
                -- Secondary guard in case the zone fires during a fast occupy.
                canInteract = function()
                    return not Crops.IsSlotOccupied(zoneKey, index)
                end,
            },
        },
    })
end

--- Show or hide the optional empty-slot prop for one plot.
---@param slot table
local function refreshProp(slot)
    local model = Config.Render.SlotProp
    if not model or model == false then return end

    local propKey = propKeyOf(slot.zone, slot.index)
    local occupied = Crops.IsSlotOccupied(slot.zone, slot.index)

    if occupied then
        Pool.Destroy(propKey)
        return
    end

    if Pool.Has(propKey) then return end

    local coords = vec3(slot.x, slot.y, slot.z)
    if Config.Render.GroundSnap then
        local found, groundZ = GetGroundZFor_3dCoord(slot.x, slot.y, slot.z + 1.0, false)
        if found and math.abs(groundZ - slot.z) < 3.0 then
            coords = vec3(slot.x, slot.y, groundZ)
        end
    end

    Pool.Create(propKey, model, coords, slot.heading or 0.0, { tag = POOL_TAG })
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Nearest empty slot to the player within `radius`.
---@param coords vector3
---@param radius? number
---@return table|nil slot
---@return number|nil distance
function Slots.NearestEmpty(coords, radius)
    radius = radius or Config.Security.MaxInteractDistance

    local best, bestDist
    for _, slot in ipairs(Sonar.Zones.AllSlots()) do
        if not Crops.IsSlotOccupied(slot.zone, slot.index) then
            local dist = Sonar.Utils.Distance(coords, slot)
            if dist <= radius and (not bestDist or dist < bestDist) then
                best, bestDist = slot, dist
            end
        end
    end

    return best, bestDist
end

--- Reconcile sphere zones and optional props with current occupancy.
--- Called from the sync tick on every render pass — cheap because it only
--- creates/destroys zones when the occupied state actually changes.
function Slots.RefreshProps()
    for _, slot in ipairs(Sonar.Zones.AllSlots()) do
        local key      = keyOf(slot.zone, slot.index)
        local entry    = registered[key]
        local occupied = Crops.IsSlotOccupied(slot.zone, slot.index)

        if not entry then
            -- Should not happen after Register(), but guard defensively.
            goto continue
        end

        if occupied and entry.zoneId then
            -- Slot just got occupied: remove the "Plant seeds" sphere so it
            -- does not fight with the crop entity target.
            Bridge.Target.RemoveZone(entry.zoneId)
            entry.zoneId = nil

        elseif not occupied and not entry.zoneId then
            -- Slot just became free: re-create the sphere so the player can
            -- see the Plant Seeds option again.
            entry.zoneId = createSphereZone(slot, key)
        end

        -- Optional visual prop.
        refreshProp(slot)

        ::continue::
    end
end

--- Register one ox_target sphere per slot at resource start.
--- All slots start as empty (server state not loaded yet). RefreshProps() will
--- drop spheres for any that turn out to be occupied once deltas arrive.
function Slots.Register()
    for _, slot in ipairs(Sonar.Zones.AllSlots()) do
        local key     = keyOf(slot.zone, slot.index)
        local propKey = propKeyOf(slot.zone, slot.index)
        local zoneId  = createSphereZone(slot, key)

        registered[key] = { zoneId = zoneId, propKey = propKey }
        refreshProp(slot)
    end

    if Config.Debug then
        Bridge.Log('info', ('Registered %d planting slots.'):format(Sonar.Zones.TotalSlots()))
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, entry in pairs(registered) do
        if entry.zoneId then
            Bridge.Target.RemoveZone(entry.zoneId)
        end
        if entry.propKey then
            Pool.Destroy(entry.propKey)
        end
    end
    registered = {}
end)
