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
function Bridge.Inventory.RemoveItem(source, item, count, metadata, slot)
    return ox:RemoveItem(source, item, count, metadata, slot) and true or false
end

--- Remove an item from one exact slot.
function Bridge.Inventory.RemoveFromSlot(source, item, count, slot, metadata)
    return Bridge.Inventory.RemoveItem(source, item, count, metadata, slot)
end

--- Return every slot containing an item. Never trust a client-provided slot.
function Bridge.Inventory.GetSlotsWithItem(source, item, metadata, strict)
    return ox:GetSlotsWithItem(source, item, metadata, strict == true) or {}
end

--- Return the first matching slot (mainly useful for compatibility callers).
function Bridge.Inventory.GetSlotWithItem(source, item, metadata, strict)
    return ox:GetSlotWithItem(source, item, metadata, strict == true)
end

function Bridge.Inventory.GetSlot(source, slot)
    return ox:GetSlot(source, slot)
end

function Bridge.Inventory.SetDurability(source, slot, durability)
    if ox:SetDurability(source, slot, durability) then return true end
    local current = ox:GetSlot(source, slot)
    if current then
        local meta = current.metadata or {}
        meta.durability = durability
        ox:SetMetadata(source, slot, meta)
        return true
    end
    return false
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
