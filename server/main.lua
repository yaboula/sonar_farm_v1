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
    Runtime.SetStatus(Runtime.STATUS.BOOTING)
    Logger.Info(('Booting sonar_farm v%s ...'):format(GetResourceMetadata(Sonar.Constants.RESOURCE, 'version', 0) or '?'), 'boot')

    local validationOk, configErrors, configWarnings = pcall(Sonar.ConfigValidation.Validate)
    if not validationOk then
        Runtime.SetStatus(Runtime.STATUS.FAILED, 'invalid_config')
        Logger.Warn(('Configuration validation crashed: %s'):format(tostring(configErrors)), 'boot')
        return
    end
    for _, warning in ipairs(configWarnings) do
        Logger.Warn(warning, 'config')
    end
    if #configErrors > 0 then
        for _, message in ipairs(configErrors) do
            Logger.Warn(message, 'config')
        end
        Runtime.SetStatus(Runtime.STATUS.FAILED, 'invalid_config')
        Logger.Warn(('Configuration validation failed with %d error(s).'):format(#configErrors), 'boot')
        return
    end

    Sonar.Utils.SeedRandom(os.time(), GetGameTimer())

    if not validateDependencies() then
        Runtime.SetStatus(Runtime.STATUS.FAILED, 'dependencies')
        Logger.Warn('Dependency check failed. Aborting initialization.', 'boot')
        return
    end

    if not Bridge.Init() then
        Runtime.SetStatus(Runtime.STATUS.FAILED, 'bridge')
        Logger.Warn('Bridge failed to initialize. Aborting.', 'boot')
        return
    end

    -- Announce readiness to any already-connected clients.
    TriggerClientEvent(Sonar.Constants.EVENTS.BRIDGE_READY, -1, Bridge.Framework)
    Logger.Info(('Bridge ready (framework: %s).'):format(Bridge.Framework), 'boot')

    -- Stage 2: state engine + persistence.
    if not Database.Init() then
        Runtime.SetStatus(Runtime.STATUS.FAILED, 'database')
        Logger.Warn('Database init failed. Gameplay remains disabled to protect persistent state.', 'boot')
        return
    end

    local loadedOk, loadedOrError = State.LoadAll()
    if not loadedOk then
        Runtime.SetStatus(Runtime.STATUS.FAILED, 'state_load')
        Logger.Warn(('State load failed: %s. Gameplay remains disabled.'):format(tostring(loadedOrError)), 'boot')
        return
    end

    local loaded = loadedOrError
    engineReady = true
    Runtime.SetStatus(Runtime.STATUS.READY)
    Logger.Info(('State engine ready (%d crops loaded). Server online.'):format(loaded), 'boot')
    TriggerClientEvent(Sonar.Constants.EVENTS.RUNTIME_READY, -1)

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
    Runtime.SetStatus(Runtime.STATUS.STOPPING)
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
