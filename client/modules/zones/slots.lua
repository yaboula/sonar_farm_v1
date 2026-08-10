--[[
    sonar_farm - Planting slots & target interactions (client)
    One ox_target sphere per nearby authoritative plot (or permanent configured
    plot while Company Field authority is disabled). Handles the full
    interaction lifecycle for a slot:
      - Empty slot    → Shows "Plant seeds"
      - Occupied slot → Shows "Inspect", "Water" (if thirsty), "Harvest" (if ready/dead)

    This guarantees the blue ox_target indicator circle ALWAYS appears reliably
    when looking at a plot (empty or planted), eliminating entity raycast hits/misses,
    missing hitboxes on tiny prop models, or target conflicts.
]]

Slots = Slots or {}

local POOL_TAG = 'slot'
local CROP_STATE = Sonar.Constants.CROP_STATE

-- [ "zone:index" ] = { zoneId = number|string, propKey = string }
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

--- Build and register the permanent ox_target sphere for one plot.
---@param slot table
---@param key string
---@return number|string zoneId
local function createSphereZone(slot, key)
    local zoneKey = slot.zone
    local index   = slot.index
    local radius  = Config.Render.SlotTargetRadius or 1.2
    local distance = Config.Render.TargetDistance or 2.2

    return Bridge.Target.AddSphereZone({
        name   = ('sonar_farm:slot:%s'):format(key),
        coords = vec3(slot.x, slot.y, slot.z),
        radius = radius,
        debug  = false,
        options = {
            {
                name     = ('sonar_farm:plant:%s'):format(key),
                label    = 'Plant crop',
                icon     = 'fa-solid fa-seedling',
                distance = distance,
                onSelect = function()
                    Actions.OpenPlantMenu(zoneKey, index)
                end,
                canInteract = function()
                    return Sync.IsAvailable() and not Crops.IsSlotOccupied(zoneKey, index)
                end,
            },
            {
                name     = ('sonar_farm:inspect:%s'):format(key),
                label    = 'Inspect',
                icon     = 'fa-solid fa-magnifying-glass',
                distance = distance,
                onSelect = function()
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if cropId then Inspection.Toggle(cropId) end
                end,
                canInteract = function()
                    return Sync.IsAvailable() and Crops.IsSlotOccupied(zoneKey, index)
                end,
            },
            {
                name     = ('sonar_farm:resume:%s'):format(key),
                label    = 'Resume planting',
                icon     = 'fa-solid fa-seedling',
                distance = distance,
                onSelect = function()
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if cropId then Minigame.Resume(cropId) end
                end,
                canInteract = function()
                    if not Sync.IsAvailable() then return false end
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    local crop = cropId and Crops.Get(cropId)
                    return crop and crop.isMine
                        and (crop.state == CROP_STATE.PLANTING or crop.state == CROP_STATE.PLANTING_FAILED)
                end,
            },
            {
                name     = ('sonar_farm:clear-incomplete:%s'):format(key),
                label    = 'Clear incomplete planting',
                icon     = 'fa-solid fa-xmark',
                distance = distance,
                onSelect = function()
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if cropId then Minigame.ClearIncomplete(cropId) end
                end,
                canInteract = function()
                    if not Sync.IsAvailable() then return false end
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    local crop = cropId and Crops.Get(cropId)
                    return crop and crop.isMine and crop.state == CROP_STATE.PLANTING_FAILED
                end,
            },
            {
                name     = ('sonar_farm:water:%s'):format(key),
                label    = 'Water',
                icon     = 'fa-solid fa-droplet',
                distance = distance,
                onSelect = function()
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if cropId then
                        Actions.OpenCareMenu('water', cropId)
                    end
                end,
                canInteract = function()
                    if not Sync.IsAvailable() then return false end
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if not cropId then return false end
                    local state = Crops.InteractionState(cropId)
                    return state and state.canWater or false
                end,
            },
            {
                name     = ('sonar_farm:harvest:%s'):format(key),
                label    = 'Harvest',
                icon     = 'fa-solid fa-wheat-awn',
                distance = distance,
                onSelect = function()
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if cropId then
                        Actions.Harvest(cropId)
                    end
                end,
                canInteract = function()
                    if not Sync.IsAvailable() then return false end
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if not cropId then return false end
                    local state = Crops.InteractionState(cropId)
                    return state and state.canHarvest or false
                end,
            },
            {
                name     = ('sonar_farm:fertilize:%s'):format(key),
                label    = 'Fertilize',
                icon     = 'fa-solid fa-flask',
                distance = distance,
                onSelect = function()
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if cropId then Actions.OpenCareMenu('fertilize', cropId) end
                end,
                canInteract = function()
                    if not Sync.IsAvailable() then return false end
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    local state = cropId and Crops.InteractionState(cropId)
                    return state and state.canFertilize or false
                end,
            },
            {
                name     = ('sonar_farm:weed:%s'):format(key),
                label    = 'Remove weeds',
                icon     = 'fa-solid fa-leaf',
                distance = distance,
                onSelect = function()
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if cropId then Actions.OpenCareMenu('weed', cropId) end
                end,
                canInteract = function()
                    if not Sync.IsAvailable() then return false end
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    local state = cropId and Crops.InteractionState(cropId)
                    return state and state.canWeed or false
                end,
            },
            {
                name     = ('sonar_farm:treat-pests:%s'):format(key),
                label    = 'Treat pests',
                icon     = 'fa-solid fa-bug',
                distance = distance,
                onSelect = function()
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    if cropId then Actions.OpenCareMenu('treat_pest', cropId) end
                end,
                canInteract = function()
                    if not Sync.IsAvailable() then return false end
                    local cropId = Crops.SlotOccupant(zoneKey, index)
                    local state = cropId and Crops.InteractionState(cropId)
                    return state and state.canTreatPests or false
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
    local source = {}
    if Config.Features.CompanyFieldAuthority then
        for _, entry in pairs(registered) do if entry.slot then source[#source + 1] = entry.slot end end
    else source = Sonar.Zones.AllSlots() end
    for _, slot in ipairs(source) do
        if not Crops.IsSlotOccupied(slot.zone, slot.index) then
            local dist = Sonar.Utils.Distance(coords, slot)
            if dist <= radius and (not bestDist or dist < bestDist) then
                best, bestDist = slot, dist
            end
        end
    end

    return best, bestDist
end

--- Reconcile optional slot props (called from sync tick).
function Slots.RefreshProps()
    if not Config.Render.SlotProp or Config.Render.SlotProp == false then
        return
    end

    if Config.Features.CompanyFieldAuthority then
        for _, entry in pairs(registered) do if entry.slot then refreshProp(entry.slot) end end
    else for _, slot in ipairs(Sonar.Zones.AllSlots()) do refreshProp(slot) end end
end

--- Register one ox_target sphere per slot at resource start.
function Slots.Register()
    if Config.Features.CompanyFieldAuthority then return end
    for _, slot in ipairs(Sonar.Zones.AllSlots()) do
        local key     = keyOf(slot.zone, slot.index)
        local propKey = propKeyOf(slot.zone, slot.index)
        local zoneId  = createSphereZone(slot, key)

        registered[key] = { zoneId = zoneId, propKey = propKey, slot = slot }
        refreshProp(slot)
    end

    if Config.Debug then
        Bridge.Log('info', ('Registered %d planting slots with unified target options.'):format(Sonar.Zones.TotalSlots()))
    end
end


--- Reconcile only the authoritative slots in the player's subscribed cells.
function Slots.ReplaceFields(fields)
    if not Config.Features.CompanyFieldAuthority then return end
    local wanted = {}
    for _, field in ipairs(fields or {}) do
        for _, slot in ipairs(field.slots or {}) do
            local key = keyOf(slot.zone, slot.index)
            wanted[key] = true
            if not registered[key] then
                registered[key] = { zoneId = createSphereZone(slot, key), propKey = propKeyOf(slot.zone, slot.index), slot = slot }
                refreshProp(slot)
            else registered[key].slot = slot end
        end
    end
    for key, entry in pairs(registered) do
        if not wanted[key] then
            if entry.zoneId then Bridge.Target.RemoveZone(entry.zoneId) end
            if entry.propKey then Pool.Destroy(entry.propKey) end
            registered[key] = nil
        end
    end
end

function Slots.ClearDynamic()
    if not Config.Features.CompanyFieldAuthority then return end
    Slots.ReplaceFields({})
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
