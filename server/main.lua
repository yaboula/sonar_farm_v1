--[[
    sonar_farm - Server bootstrap
    Validates dependencies, initializes the Bridge, boots the state/persistence
    engine (Stage 2), starts the periodic save loop, and flushes on shutdown.
]]

-- Hard runtime dependencies (the framework core is validated by the Bridge).
local REQUIRED_RESOURCES = { 'ox_lib', 'ox_inventory', 'ox_target', 'oxmysql' }

-- True once the state engine has loaded and the save loop is running.
local engineReady = false

--- Ensure all required resources are started. Returns false and logs on failure.
---@return boolean ok
local function validateDependencies()
    local missing = {}
    for _, res in ipairs(REQUIRED_RESOURCES) do
        if GetResourceState(res) ~= 'started' then
            missing[#missing + 1] = res
        end
    end

    if #missing > 0 then
        Logger.Warn(
            ('Missing required resources: %s. Start them before sonar_farm.'):format(table.concat(missing, ', ')),
            'boot'
        )
        return false
    end
    return true
end

CreateThread(function()
    Logger.Info(('Booting sonar_farm v%s ...'):format(GetResourceMetadata(Sonar.Constants.RESOURCE, 'version', 0) or '?'), 'boot')

    if not validateDependencies() then
        Logger.Warn('Dependency check failed. Aborting initialization.', 'boot')
        return
    end

    if not Bridge.Init() then
        Logger.Warn('Bridge failed to initialize. Aborting.', 'boot')
        return
    end

    -- Announce readiness to any already-connected clients.
    TriggerClientEvent(Sonar.Constants.EVENTS.BRIDGE_READY, -1, Bridge.Framework)
    Logger.Info(('Bridge ready (framework: %s).'):format(Bridge.Framework), 'boot')

    -- Stage 2: state engine + persistence.
    if not Database.Init() then
        Logger.Warn('Database init failed. State engine disabled (running without persistence).', 'boot')
        return
    end

    local loaded = State.LoadAll()
    engineReady = true
    Logger.Info(('State engine ready (%d crops loaded). Server online.'):format(loaded), 'boot')

    -- Periodic async batch save of dirty state.
    CreateThread(function()
        local interval = (Config.SaveInterval or 60) * 1000
        while true do
            Wait(interval)
            State.Flush()
        end
    end)
end)

-- Emergency flush on resource stop / server shutdown (txAdmin hot updates).
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= Sonar.Constants.RESOURCE then return end
    if not engineReady then return end
    Logger.Info('Resource stopping: flushing state to database.', 'boot')
    State.FlushSync()
end)

-- Late-joining clients ask the server which framework is active once loaded.
RegisterNetEvent(Sonar.Constants.EVENTS.BRIDGE_READY, function()
    local src = source
    if Bridge.Ready then
        TriggerClientEvent(Sonar.Constants.EVENTS.BRIDGE_READY, src, Bridge.Framework)
    end
end)
