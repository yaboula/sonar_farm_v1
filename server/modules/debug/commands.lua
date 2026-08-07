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

local function canRun(src)
    if Admin.IsAuthorized(src) then
        return true
    end
    reply(src, 'Permission denied. Required ACE: ' .. Config.Admin.Ace)
    return false
end

local function runtimeReady(src)
    if Runtime.IsReady() then
        return true
    end
    reply(src, ('Runtime is %s; command rejected.'):format(Runtime.status))
    return false
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
    if not canRun(src) or not runtimeReady(src) then return end
    local cropType = args[1] or 'carrot'
    local growthTime = tonumber(args[2]) or 300
    if not Config.Crops[cropType] then
        reply(src, ('Unknown crop type: %s'):format(tostring(cropType)))
        return
    end
    if growthTime <= 0 then
        reply(src, 'growthTime must be a positive number.')
        return
    end
    local x, y, z, h = resolveCoords(src)

    local id, record = State.Add({
        crop_type = cropType,
        owner = (src and src > 0) and Bridge.GetIdentifier(src) or nil,
        zone = 'debug',
        pos_x = x, pos_y = y, pos_z = z, heading = h,
        planted_at = Sonar.Time.Now(),
        growth_time = growthTime,
        data = { water = 100, health = 100, lastCare = Sonar.Time.Now() },
    })

    -- Keep subscribed clients in sync, or the debug crop renders for nobody
    -- until they cross a cell boundary.
    Sync.OnCropChanged(record)

    reply(src, ('Planted %s (id=%s, growth=%ds) at %.1f, %.1f, %.1f'):format(cropType, id, growthTime, x, y, z))
end, false)

-- /farm_debug_dump
RegisterCommand('farm_debug_dump', function(src)
    if not canRun(src) or not runtimeReady(src) then return end
    local dirty, deleted, cells = 0, 0, 0
    for _ in pairs(State.dirty) do dirty = dirty + 1 end
    for _ in pairs(State.deleted) do deleted = deleted + 1 end
    for _ in pairs(State.cells) do cells = cells + 1 end
    reply(src, ('crops=%d dirty=%d deleted=%d cells=%d loaded=%s')
        :format(State.Count(), dirty, deleted, cells, tostring(State.loaded)))
end, false)

-- /farm_debug_grow [id]
RegisterCommand('farm_debug_grow', function(src, args)
    if not canRun(src) or not runtimeReady(src) then return end
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
    if not canRun(src) or not runtimeReady(src) then return end
    CreateThread(function()
        local ok = State.Flush()
        reply(src, ('Flush %s'):format(ok and 'OK' or 'FAILED'))
    end)
end, false)

-- /farm_debug_clear
RegisterCommand('farm_debug_clear', function(src)
    if not canRun(src) or not runtimeReady(src) then return end
    local targets = {}
    for id, record in pairs(State.crops) do
        targets[#targets + 1] = { id = id, cell = record.cell }
    end
    for _, target in ipairs(targets) do
        State.Remove(target.id)
        Sync.OnCropRemoved(target.id, target.cell)
    end
    reply(src, ('Cleared %d crops (queued for deletion).'):format(#targets))
end, false)

Logger.Info('Debug commands registered (/farm_debug_plant|dump|grow|save|clear).', 'debug')
