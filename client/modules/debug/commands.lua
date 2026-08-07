--[[
    sonar_farm - Client test commands
    Shortcuts for testing without hunting for a prop to aim at. Everything routes
    through the Actions layer, so these exercise exactly the same path as the
    ox_target interactions: no special-cased debug logic anywhere.

    Registered only when Config.Debug is true.
]]

if not Config.Debug then return end

local NOTIFY = Sonar.Constants.NOTIFY

--- The crop the player is standing next to, when no id is given.
---@param provided string|nil
---@return string|nil
local function resolveCropId(provided)
    if provided and provided ~= '' then return provided end

    local cropId = Crops.Closest(GetEntityCoords(PlayerPedId()))
    return cropId
end

-- /farm_plant [cropType]  — plants into the nearest empty slot (never free-plant).
RegisterCommand('farm_plant', function(_, args)
    local cropType = args[1] or 'carrot'
    local slot = Slots.NearestEmpty(GetEntityCoords(PlayerPedId()), 5.0)

    if not slot then
        return Bridge.Notify('No empty planting plot nearby.', NOTIFY.ERROR)
    end

    Actions.Plant(cropType, slot.zone, slot.index)
end, false)

RegisterCommand('farm_water', function(_, args)
    local cropId = resolveCropId(args[1])
    if not cropId then
        return Bridge.Notify('No crop nearby.', NOTIFY.ERROR)
    end
    Actions.Water(cropId)
end, false)

RegisterCommand('farm_harvest', function(_, args)
    local cropId = resolveCropId(args[1])
    if not cropId then
        return Bridge.Notify('No crop nearby.', NOTIFY.ERROR)
    end
    Actions.Harvest(cropId)
end, false)

-- Inspect the local cache and what is actually rendered. This is the command to
-- reach for when something looks wrong on screen: it separates "the server never
-- told me" from "I know about it but did not draw it".
RegisterCommand('farm_render', function()
    local coords = GetEntityCoords(PlayerPedId())

    Bridge.Notify(('Cached %d crop(s), %d prop(s), %d slots. See F8.')
        :format(Crops.Count(), Pool.Count(), Sonar.Zones.TotalSlots()), NOTIFY.INFO)

    print(('[sonar_farm] cache=%d props=%d slots=%d clockOffset=%ds interior=%s')
        :format(Crops.Count(), Pool.Count(), Sonar.Zones.TotalSlots(),
            Sonar.Time.Offset(), tostring(GetInteriorFromEntity(PlayerPedId()) ~= 0)))

    for _, cropId in ipairs(Pool.Keys()) do
        local record = Crops.Get(cropId)
        local condition = Crops.Condition(cropId)
        if record and condition then
            print(('[sonar_farm] %s | %s | zone=%s slot=%s | %.1fm | %s | growth %d%% | water %d%% | health %d%% | mine=%s | model=%s')
                :format(cropId, record.crop_type, tostring(record.zone), tostring(record.slot),
                    Sonar.Utils.Distance(coords, { x = record.pos_x, y = record.pos_y, z = record.pos_z }),
                    condition.state, math.floor(condition.progress * 100),
                    math.floor(condition.water), math.floor(condition.health),
                    tostring(record.isMine), tostring(Pool.ModelOf(cropId))))
        end
    end
end, false)

-- Force a resubscription. Useful after editing zones or crops on a live server.
RegisterCommand('farm_resync', function()
    Sync.RefreshNow()
    Bridge.Notify(('Resynced. %d crop(s) cached.'):format(Crops.Count()), NOTIFY.INFO)
end, false)
