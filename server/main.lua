--[[
    sonar_farm - Server bootstrap
    Validates hard dependencies, initializes the Bridge, and signals readiness.
    No farming logic here yet (Stage 3+). This is the smoke test for Stage 1.
]]

-- Hard runtime dependencies (the framework core is validated by the Bridge).
local REQUIRED_RESOURCES = { 'ox_lib', 'ox_inventory', 'ox_target' }

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

    Logger.Info(('Bridge ready (framework: %s). Server online.'):format(Bridge.Framework), 'boot')
end)

-- Late-joining clients ask the server which framework is active once loaded.
RegisterNetEvent(Sonar.Constants.EVENTS.BRIDGE_READY, function()
    local src = source
    if Bridge.Ready then
        TriggerClientEvent(Sonar.Constants.EVENTS.BRIDGE_READY, src, Bridge.Framework)
    end
end)
