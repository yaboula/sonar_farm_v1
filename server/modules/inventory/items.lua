-- Authoritative item selection, company ownership checks and tool wear.

Items = Items or {}

local REJECT = Sonar.Constants.REJECT

local function effectFor(item)
    return item.tool or item.consumable
end

local function actionFor(item)
    local effect = effectFor(item)
    return effect and effect.action
end

local function durabilityOf(slot)
    local value = slot and slot.metadata and tonumber(slot.metadata.durability)
    return Sonar.Utils.Clamp(value or 100, 0, 100)
end

local function memberCanUse(source, metadata)
    if type(metadata) ~= 'table' or metadata.ownership ~= 'company' then return true end
    return Company and Company.CanUseIssuedItem and Company.CanUseIssuedItem(source, metadata)
end

local function usableSlots(source, item)
    local result = {}
    for _, slot in pairs(Bridge.Inventory.GetSlotsWithItem(source, item.id) or {}) do
        if memberCanUse(source, slot.metadata)
            and (not item.tool or durabilityOf(slot) > 0) then
            result[#result + 1] = slot
        end
    end
    table.sort(result, function(a, b)
        local left, right = durabilityOf(a), durabilityOf(b)
        if left == right then return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0) end
        return left < right
    end)
    return result
end

function Items.Get(itemId)
    return type(itemId) == 'string' and Sonar.ItemCatalog.byId[itemId] or nil
end

function Items.Resolve(source, action, itemId)
    local item = Items.Get(itemId)
    if not item or actionFor(item) ~= action then return nil, REJECT.MISSING_TOOL end
    local slots = usableSlots(source, item)
    if #slots == 0 then return nil, REJECT.MISSING_TOOL end
    local slot = slots[1]
    return {
        definition = item,
        effect = effectFor(item),
        slot = tonumber(slot.slot),
        count = tonumber(slot.count) or 1,
        metadata = slot.metadata or {},
        durability = durabilityOf(slot),
    }
end

function Items.ListForAction(source, action, record)
    local options = {}
    for _, item in ipairs(Sonar.ItemCatalog.items) do
        local effect = effectFor(item)
        if effect and effect.action == action then
            local slots = usableSlots(source, item)
            if #slots > 0 then
                local count, totalUses = 0, 0
                for _, slot in ipairs(slots) do
                    count = count + (tonumber(slot.count) or 1)
                    if item.tool then
                        totalUses = totalUses + math.ceil(durabilityOf(slot) / 100 * item.tool.uses - 0.0001)
                    end
                end
                local resolvedProtectionSeconds = record
                    and Sonar.CropClock.ProtectionSeconds(record, effect) or 0
                options[#options + 1] = {
                    id = item.id,
                    label = item.label,
                    tier = item.tier,
                    count = count,
                    usesRemaining = item.tool and totalUses or count,
                    effect = effect,
                    protectionSeconds = resolvedProtectionSeconds,
                    protectionCycleRatio = record and Sonar.CropClock.IsV2(record)
                        and (tonumber(effect.protectionCycleRatio) or 0) or 0,
                    description = item.description,
                }
            end
        end
    end
    table.sort(options, function(a, b)
        return (Sonar.ItemCatalog.tiers[a.tier] or 0) < (Sonar.ItemCatalog.tiers[b.tier] or 0)
    end)
    return options
end

--- Consume one application from a previously server-resolved item.
---@return boolean ok
---@return boolean broken
function Items.Consume(source, resolved)
    local item = resolved and resolved.definition
    if not item or not resolved.slot then return false, false end

    local predictedBroken = item.tool and (resolved.durability - 100 / item.tool.uses <= 0.0001) or false
    local usageOutboxId
    if type(resolved.metadata) == 'table' and resolved.metadata.ownership == 'company' then
        local prepared, outboxId, usagePayload = Company.PrepareItemUse(source, resolved.metadata, effectFor(item).action, resolved, predictedBroken)
        if not prepared then return false, false end
        usageOutboxId = outboxId
        resolved.usageOutboxId = outboxId
        resolved.usagePayload = usagePayload
    end

    if item.consumable then
        local removed = Bridge.Inventory.RemoveFromSlot(source, item.id, 1, resolved.slot, resolved.metadata)
        if not removed then Company.CancelItemUse(usageOutboxId) end
        return removed, false
    end

    local decrement = 100 / item.tool.uses
    local remaining = math.max(0, resolved.durability - decrement)
    if remaining <= 0.0001 then
        local removed = Bridge.Inventory.RemoveFromSlot(source, item.id, 1, resolved.slot, resolved.metadata)
        if not removed then Company.CancelItemUse(usageOutboxId) end
        return removed, removed
    end
    local changed = Bridge.Inventory.SetDurability(source, resolved.slot, remaining)
    if not changed then Company.CancelItemUse(usageOutboxId) end
    return changed, false
end

function Items.RecordCompanyUse(source, resolved, action, broken)
    local metadata = resolved and resolved.metadata
    if type(metadata) == 'table' and metadata.ownership == 'company'
        and Company and Company.RecordItemUse then
        Company.RecordItemUse(source, metadata, action, broken, resolved.usageOutboxId, resolved.usagePayload)
    end
end
