--[[
    sonar_farm - Empty planting slots (client)
    One ox_target point per configured plot. Free-planting is gone: the only way
    to plant is to look at an empty slot and pick a seed.

    Occupancy is derived from the local crop cache (which the sync layer keeps
    current). canInteract hides the Plant option the moment a crop lands in the
    slot, including when another player planted it.

    Optional SlotProp draws a marker on empty plots. Off by default: sixty-odd
    extra entities for aesthetics is a choice each server can make.
]]

Slots = Slots or {}

local POOL_TAG = 'slot'
-- [ "zone:index" ] = { zoneId = number|string, propKey = string|nil }
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

--- Reconcile optional slot props with occupancy (called from the sync tick).
function Slots.RefreshProps()
    if not Config.Render.SlotProp or Config.Render.SlotProp == false then
        return
    end

    for _, slot in ipairs(Sonar.Zones.AllSlots()) do
        refreshProp(slot)
    end
end

--- Register one ox_target sphere per slot. Planting is discoverable by looking
--- at the plot itself — the gesture Roleplay expects.
function Slots.Register()
    local radius = Config.Render.SlotTargetRadius or 1.2

    for _, slot in ipairs(Sonar.Zones.AllSlots()) do
        local key = keyOf(slot.zone, slot.index)
        local zoneKey = slot.zone
        local index = slot.index

        local zoneId = Bridge.Target.AddSphereZone({
            name = ('sonar_farm:slot:%s'):format(key),
            coords = vec3(slot.x, slot.y, slot.z),
            radius = radius,
            debug = false,
            options = {
                {
                    name = ('sonar_farm:plant:%s'):format(key),
                    label = 'Plant seeds',
                    icon = 'fa-solid fa-seedling',
                    distance = Config.Render.TargetDistance,
                    onSelect = function()
                        Actions.OpenPlantMenu(zoneKey, index)
                    end,
                    canInteract = function()
                        return not Crops.IsSlotOccupied(zoneKey, index)
                    end,
                },
            },
        })

        registered[key] = { zoneId = zoneId, propKey = propKeyOf(zoneKey, index) }
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
