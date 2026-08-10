--[[
    sonar_farm - Action FX relay (server)
    Listens to the public crop events and rebroadcasts a presentation-only
    client event so nearby players see/hear the same field work. Never mutates
    crop state; skips the acting player (they already play local FX).
]]

local PUBLIC = Sonar.Constants.PUBLIC_EVENTS
local EVENTS = Sonar.Constants.EVENTS

local MAX_DISTANCE = 45.0
local MAX_DISTANCE_SQ = MAX_DISTANCE * MAX_DISTANCE

local ACTION_BY_EVENT = {
    [PUBLIC.CROP_PLANTED] = 'plant',
    [PUBLIC.CROP_WATERED] = 'water',
    [PUBLIC.CROP_FERTILIZED] = 'fertilize',
    [PUBLIC.CROP_WEEDED] = 'weed',
    [PUBLIC.CROP_TREATED] = 'treat_pest',
    [PUBLIC.CROP_HARVESTED] = 'harvest',
}

---@param action string
---@param payload table
---@return number|nil, number|nil, number|nil
local function resolveCoords(action, payload)
    if action == 'harvest' then
        local ped = GetPlayerPed(payload.source)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            return coords.x, coords.y, coords.z
        end
        return nil
    end

    local record = payload.cropId and State.Get(payload.cropId)
    if record then
        return record.pos_x, record.pos_y, record.pos_z
    end

    if payload.zone and payload.slot then
        local slot = Sonar.Zones.Slot(payload.zone, payload.slot)
        if slot then
            return slot.x, slot.y, slot.z
        end
    end

    return nil
end

---@param action string
---@param payload table
local function broadcast(action, payload)
    local source = tonumber(payload.source)
    if not source then return end

    local x, y, z = resolveCoords(action, payload)
    if not x then return end

    local packet = {
        action = action,
        source = source,
        x = x,
        y = y,
        z = z,
    }

    for _, id in ipairs(GetPlayers()) do
        local sid = tonumber(id)
        if sid and sid ~= source then
            local ped = GetPlayerPed(sid)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local dx = coords.x - x
                local dy = coords.y - y
                local dz = coords.z - z
                if (dx * dx + dy * dy + dz * dz) <= MAX_DISTANCE_SQ then
                    TriggerClientEvent(EVENTS.ACTION_FX, sid, packet)
                end
            end
        end
    end
end

for eventName, action in pairs(ACTION_BY_EVENT) do
    AddEventHandler(eventName, function(payload)
        if type(payload) ~= 'table' then return end
        broadcast(action, payload)
    end)
end
