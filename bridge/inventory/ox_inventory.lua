--[[
    sonar_farm - Bridge wrapper: ox_inventory
    Thin, server-authoritative wrapper over ox_inventory exports. Populates
    Bridge.Inventory. All item mutations happen on the server by design; the
    metadata field carries crop attributes (quality, freshness, moisture).
]]

if not IsDuplicityVersion() then
    -- Client context: item mutations are server-only. Expose read helpers only.
    Bridge.Inventory.GetItemCount = function(item, metadata)
        return exports.ox_inventory:Search('count', item, metadata)
    end
    return
end

local ox = exports.ox_inventory

--- Give an item to a player.
---@param source number
---@param item string
---@param count number
---@param metadata? table
---@return boolean success
function Bridge.Inventory.AddItem(source, item, count, metadata)
    return ox:AddItem(source, item, count, metadata) and true or false
end

--- Remove an item from a player.
---@param source number
---@param item string
---@param count number
---@param metadata? table
---@return boolean success
function Bridge.Inventory.RemoveItem(source, item, count, metadata)
    return ox:RemoveItem(source, item, count, metadata) and true or false
end

--- Count how many of `item` a player holds (optionally matching metadata).
---@param source number
---@param item string
---@param metadata? table
---@return number count
function Bridge.Inventory.GetItemCount(source, item, metadata)
    return ox:GetItemCount(source, item, metadata) or 0
end

--- Whether a player holds at least `count` of `item`.
---@param source number
---@param item string
---@param count? number defaults to 1
---@param metadata? table
---@return boolean
function Bridge.Inventory.HasItem(source, item, count, metadata)
    return Bridge.Inventory.GetItemCount(source, item, metadata) >= (count or 1)
end

--- Whether a player can carry `count` of `item` (weight/slots check).
---@param source number
---@param item string
---@param count number
---@return boolean
function Bridge.Inventory.CanCarry(source, item, count)
    return ox:CanCarryItem(source, item, count) and true or false
end
