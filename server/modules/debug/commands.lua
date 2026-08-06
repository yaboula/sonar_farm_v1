--[[
    sonar_farm - Debug commands (server)
    Test harness for the Stage 2 state/persistence engine. Registered ONLY when
    Config.Debug is true. Not meant for production. No real gameplay here.
]]

if not Config.Debug then return end

local function reply(src, msg)
    if src and src > 0 then
        TriggerClientEvent('chat:addMessage', src, { args = { '^2[farm_debug]', msg } })
    end
    Logger.Info(msg, 'debug')
end

--- Resolve spawn coordinates for a command caller (player ped or a default).
local function resolveCoords(src)
    if src and src > 0 then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            return c.x, c.y, c.z, GetEntityHeading(ped)
        end
    end
    -- Console fallback: Grapeseed fields.
    return 2260.0, 4880.0, 41.0, 0.0
end

-- /farm_debug_plant [cropType] [growthTime]
RegisterCommand('farm_debug_plant', function(src, args)
    local cropType = args[1] or 'debug_crop'
    local growthTime = tonumber(args[2]) or 300
    local x, y, z, h = resolveCoords(src)

    local id = State.Add({
        crop_type = cropType,
        owner = (src and src > 0) and Bridge.GetIdentifier(src) or nil,
        zone = 'debug',
        pos_x = x, pos_y = y, pos_z = z, heading = h,
        growth_time = growthTime,
        data = { water = 100, health = 100 },
    })

    reply(src, ('Planted %s (id=%s, growth=%ds) at %.1f, %.1f, %.1f'):format(cropType, id, growthTime, x, y, z))
end, false)

-- /farm_debug_dump
RegisterCommand('farm_debug_dump', function(src)
    local dirty, deleted, cells = 0, 0, 0
    for _ in pairs(State.dirty) do dirty = dirty + 1 end
    for _ in pairs(State.deleted) do deleted = deleted + 1 end
    for _ in pairs(State.cells) do cells = cells + 1 end
    reply(src, ('crops=%d dirty=%d deleted=%d cells=%d loaded=%s')
        :format(State.Count(), dirty, deleted, cells, tostring(State.loaded)))
end, false)

-- /farm_debug_grow [id]
RegisterCommand('farm_debug_grow', function(src, args)
    local id = args[1]
    local record = id and State.Get(id)
    if not record then
        reply(src, ('No crop with id=%s'):format(tostring(id)))
        return
    end
    local g = Growth.Evaluate(record)
    reply(src, ('crop=%s type=%s state=%s progress=%.2f stage=%d elapsed=%ds')
        :format(record.id, record.crop_type, g.state, g.progress, g.stageIndex, g.elapsed))
end, false)

-- /farm_debug_save
RegisterCommand('farm_debug_save', function(src)
    CreateThread(function()
        local ok = State.Flush()
        reply(src, ('Flush %s'):format(ok and 'OK' or 'FAILED'))
    end)
end, false)

-- /farm_debug_clear
RegisterCommand('farm_debug_clear', function(src)
    local ids = {}
    for id in pairs(State.crops) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do State.Remove(id) end
    reply(src, ('Cleared %d crops (queued for deletion).'):format(#ids))
end, false)

Logger.Info('Debug commands registered (/farm_debug_plant|dump|grow|save|clear).', 'debug')
