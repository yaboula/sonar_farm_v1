--[[
    sonar_farm - Client bootstrap
    Initializes the Bridge on the client and waits for readiness. No visual or
    interaction logic yet (Stage 4+). This is the client-side smoke test.
]]

CreateThread(function()
    if not Bridge.Init() then
        Bridge.Log('error', 'Client Bridge failed to initialize.')
        return
    end

    Bridge.OnReady(function()
        Bridge.Log('info', ('Client Bridge ready (framework: %s).'):format(Bridge.Framework))
    end)

    -- Let the server know we are loaded so it can confirm the active framework.
    TriggerServerEvent(Sonar.Constants.EVENTS.BRIDGE_READY)
end)

-- Server confirms which framework is authoritative.
RegisterNetEvent(Sonar.Constants.EVENTS.BRIDGE_READY, function(framework)
    if Config.Debug then
        Bridge.Log('info', ('Server confirmed active framework: %s'):format(tostring(framework)))
    end
end)
