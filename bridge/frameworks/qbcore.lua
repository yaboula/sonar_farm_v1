--[[
    sonar_farm - Bridge adapter: QB-Core (MVP, full implementation)
    Registers itself into the Bridge registry. Implements server- and
    client-context methods, branching on IsDuplicityVersion().
]]

local FRAMEWORK = Sonar.Constants.FRAMEWORKS.QBCORE
local NOTIFY = Sonar.Constants.NOTIFY

local QBCore

local adapter = {}

--- Acquire the QB-Core object. Supports the modern export entrypoint.
function adapter.Init()
    local resName = Config.FrameworkResources[FRAMEWORK]
    QBCore = exports[resName]:GetCoreObject()
    if not QBCore then
        error('GetCoreObject() returned nil for ' .. resName)
    end
end

if IsDuplicityVersion() then
    -- =====================================================================
    -- SERVER CONTEXT
    -- =====================================================================

    ---@param source number
    ---@return table|nil
    function adapter.GetPlayer(source)
        return QBCore.Functions.GetPlayer(source)
    end

    ---@param source number
    ---@return string|nil citizenid
    function adapter.GetIdentifier(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return nil end
        return player.PlayerData.citizenid
    end

    ---@param identifier string citizenid
    ---@return table|nil
    function adapter.GetPlayerByIdentifier(identifier)
        return QBCore.Functions.GetPlayerByCitizenId(identifier)
    end

    ---@param source number
    ---@return string
    function adapter.GetPlayerName(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return ('Unknown (%s)'):format(source) end
        local info = player.PlayerData.charinfo
        if info then
            return ('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s*(.-)%s*$', '%1')
        end
        return player.PlayerData.name or ('Player %s'):format(source)
    end

    --- Notify a client from the server via ox_lib.
    ---@param source number
    ---@param message string
    ---@param ntype? string ox_lib notify type
    function adapter.Notify(source, message, ntype)
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Farming',
            description = message,
            type = ntype or NOTIFY.INFO,
        })
    end
else
    -- =====================================================================
    -- CLIENT CONTEXT
    -- =====================================================================

    ---@return table PlayerData
    function adapter.GetPlayerData()
        return QBCore.Functions.GetPlayerData()
    end

    --- Local ox_lib notification.
    ---@param message string
    ---@param ntype? string ox_lib notify type
    function adapter.Notify(message, ntype)
        lib.notify({
            title = 'Farming',
            description = message,
            type = ntype or NOTIFY.INFO,
        })
    end
end

Bridge.RegisterFramework(FRAMEWORK, adapter)
