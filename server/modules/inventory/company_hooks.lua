-- Prevent Company-owned material from leaving its issued player inventory.

CompanyInventoryHooks = CompanyInventoryHooks or {}
local hookId

function CompanyInventoryHooks.Init()
    if hookId then return true end
    hookId = exports.ox_inventory:registerHook('swapItems', function(payload)
        local from = payload and payload.fromSlot
        local metadata = type(from) == 'table' and from.metadata or nil
        if type(metadata) ~= 'table' or metadata.ownership ~= 'company' then return true end

        local sameInventory = tostring(payload.fromInventory) == tostring(payload.toInventory)
        local playerMove = payload.fromType == 'player' and payload.toType == 'player' and sameInventory
        if playerMove then return true end

        Logger.Warn(('Blocked Company material transfer (%s -> %s, issue %s)')
            :format(tostring(payload.fromType), tostring(payload.toType), tostring(metadata.issueId)), 'inventory')
        return false
    end, { print = false })
    return hookId ~= nil
end

function CompanyInventoryHooks.Shutdown()
    if hookId then exports.ox_inventory:removeHooks(hookId); hookId = nil end
end
