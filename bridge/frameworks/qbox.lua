--[[
    sonar_farm - Bridge adapter: Qbox (decoupled stub)
    Interface placeholder so the Bridge contract is enforced across frameworks.
    Implement these methods to add first-class Qbox support (mirror qbcore.lua).
]]

local FRAMEWORK = Sonar.Constants.FRAMEWORKS.QBOX

local adapter = {}

local function notImplemented(method)
    Bridge.Log('error', ('Qbox adapter method "%s" is not implemented yet.'):format(method))
    return nil
end

function adapter.Init()
    Bridge.Log('warn', 'Qbox adapter is a stub. First-class Qbox support is not implemented yet.')
end

if IsDuplicityVersion() then
    function adapter.GetPlayer() return notImplemented('GetPlayer') end
    function adapter.GetIdentifier() return notImplemented('GetIdentifier') end
    function adapter.GetPlayerByIdentifier() return notImplemented('GetPlayerByIdentifier') end
    function adapter.GetPlayerName() return notImplemented('GetPlayerName') end
    function adapter.Notify() return notImplemented('Notify') end
else
    function adapter.GetPlayerData() return notImplemented('GetPlayerData') end
    function adapter.Notify() return notImplemented('Notify') end
end

Bridge.RegisterFramework(FRAMEWORK, adapter)
