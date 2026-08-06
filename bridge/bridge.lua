--[[
    sonar_farm - Bridge Layer (Module 1)
    Framework abstraction. The rest of the codebase talks ONLY to `Bridge.*`
    and never to a framework object directly. This keeps QB-Core (MVP) swappable
    for ESX / Qbox later without touching business logic.

    Load order (see fxmanifest): bridge.lua first, then framework adapters and
    the inventory/target wrappers register themselves into this registry.

    Context: runs on both client and server (shared_script). Adapters expose the
    methods relevant to their runtime context (checked via IsDuplicityVersion()).
]]

Bridge = Bridge or {}

Bridge.Ready = false
Bridge.Framework = nil
Bridge.Adapter = nil

-- Registries populated by adapter/wrapper files at load time.
Bridge._adapters = Bridge._adapters or {}
Bridge.Inventory = Bridge.Inventory or {}
Bridge.Target = Bridge.Target or {}

local readyCallbacks = {}

-- ---------------------------------------------------------------------------
-- Internal logging (Bridge must not depend on the server-only Logger module).
-- ---------------------------------------------------------------------------
local PREFIX = '^5[sonar_farm]^7'

--- Minimal internal print, safe on client and server.
---@param level 'info'|'warn'|'error'
---@param message string
function Bridge.Log(level, message)
    local color = level == 'error' and '^1' or (level == 'warn' and '^3' or '^2')
    print(('%s %s[%s]^7 %s'):format(PREFIX, color, level:upper(), message))
end

-- ---------------------------------------------------------------------------
-- Registration API (called by adapter files at load time)
-- ---------------------------------------------------------------------------

--- Register a framework adapter under a canonical name.
---@param name string One of Sonar.Constants.FRAMEWORKS.
---@param adapter table Table of interface functions.
function Bridge.RegisterFramework(name, adapter)
    Bridge._adapters[name] = adapter
end

-- ---------------------------------------------------------------------------
-- Detection
-- ---------------------------------------------------------------------------

--- Resolve which framework to use, honoring Config.Framework override or
--- auto-detecting a started core resource.
---@return string|nil name
function Bridge.Detect()
    local configured = Config and Config.Framework or 'auto'

    if configured and configured ~= 'auto' then
        local resName = Config.FrameworkResources[configured]
        if resName and GetResourceState(resName) == 'started' then
            return configured
        end
        -- Forced but not (yet) started: return it so Init can keep waiting.
        return configured
    end

    for name, resName in pairs(Config.FrameworkResources) do
        if GetResourceState(resName) == 'started' then
            return name
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Initialization (must be called from within a thread; it may Wait())
-- ---------------------------------------------------------------------------

--- Detect the framework, wait for its core resource, and activate the adapter.
--- Idempotent: safe to call multiple times.
---@return boolean ok
function Bridge.Init()
    if Bridge.Ready then return true end

    -- Wait for a supported framework to be present (max ~10s).
    local name
    local attempts = 0
    repeat
        name = Bridge.Detect()
        if not name then
            attempts = attempts + 1
            Wait(100)
        end
    until name or attempts >= 100

    if not name then
        Bridge.Log('error', 'No supported framework detected (qb-core / esx / qbox). Bridge halted.')
        return false
    end

    local adapter = Bridge._adapters[name]
    if not adapter then
        Bridge.Log('error', ('Framework "%s" detected but no adapter is registered.'):format(name))
        return false
    end

    -- Wait for the framework core resource to actually be started.
    local resName = Config.FrameworkResources[name]
    attempts = 0
    while GetResourceState(resName) ~= 'started' and attempts < 100 do
        attempts = attempts + 1
        Wait(100)
    end

    if GetResourceState(resName) ~= 'started' then
        Bridge.Log('error', ('Framework core "%s" never reached "started" state. Bridge halted.'):format(resName))
        return false
    end

    Bridge.Framework = name
    Bridge.Adapter = adapter

    if adapter.Init then
        local ok, err = pcall(adapter.Init)
        if not ok then
            Bridge.Log('error', ('Adapter "%s" failed to init: %s'):format(name, tostring(err)))
            return false
        end
    end

    Bridge.Ready = true
    Bridge.Log('info', ('Bridge ready (framework: %s).'):format(name))

    for _, cb in ipairs(readyCallbacks) do
        pcall(cb)
    end
    readyCallbacks = {}

    return true
end

--- Run `cb` when the Bridge is ready (immediately if it already is).
---@param cb fun()
function Bridge.OnReady(cb)
    if Bridge.Ready then
        pcall(cb)
    else
        readyCallbacks[#readyCallbacks + 1] = cb
    end
end

-- ---------------------------------------------------------------------------
-- Guarded delegation helper
-- ---------------------------------------------------------------------------
local function callAdapter(method, ...)
    if not Bridge.Ready or not Bridge.Adapter then
        Bridge.Log('error', ('Bridge.%s called before the Bridge was ready.'):format(method))
        return nil
    end
    local fn = Bridge.Adapter[method]
    if not fn then
        Bridge.Log('error', ('Adapter "%s" does not implement "%s" for this context.'):format(tostring(Bridge.Framework), method))
        return nil
    end
    return fn(...)
end

-- ---------------------------------------------------------------------------
-- Public interface (delegates to the active adapter)
-- Server-context methods take a `source`; client-context methods do not.
-- ---------------------------------------------------------------------------

--- [Server] Get the framework-native player object for a source.
function Bridge.GetPlayer(source)
    return callAdapter('GetPlayer', source)
end

--- [Server] Get the stable character identifier (citizenid) for a source.
function Bridge.GetIdentifier(source)
    return callAdapter('GetIdentifier', source)
end

--- [Server] Get a player object by character identifier.
function Bridge.GetPlayerByIdentifier(identifier)
    return callAdapter('GetPlayerByIdentifier', identifier)
end

--- [Server] Get a display name for a source.
function Bridge.GetPlayerName(source)
    return callAdapter('GetPlayerName', source)
end

--- [Client] Get the local player's framework data table.
function Bridge.GetPlayerData()
    return callAdapter('GetPlayerData')
end

--- Notify a player. Server: Notify(source, message, type). Client: Notify(message, type).
function Bridge.Notify(...)
    return callAdapter('Notify', ...)
end
