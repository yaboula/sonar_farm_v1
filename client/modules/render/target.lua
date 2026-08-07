--[[
    sonar_farm - Crop interaction (client)
    Exposes helper utilities and descriptors for crop target options.
    Slot sphere zones (in client/modules/zones/slots.lua) are the primary target
    entry-points for all slot interactions (Plant, Inspect, Water, Harvest).
]]

Target = Target or {}

local CROP_STATE = Sonar.Constants.CROP_STATE

--- Human-readable condition summary for the inspect option.
---@param cropId string
---@return string
function Target.Describe(cropId)
    local record = Crops.Get(cropId)
    local condition = Crops.Condition(cropId)
    if not record or not condition then return 'Unknown crop.' end

    local def = Config.Crops and Config.Crops[record.crop_type]
    local label = (def and def.label) or record.crop_type

    if condition.state == CROP_STATE.DEAD then
        return ('%s: dead. Harvest to clear the plot.'):format(label)
    end

    if condition.progress >= 1 then
        return ('%s: ready to harvest. Health %d%%.'):format(label, math.floor(condition.health))
    end

    return ('%s: %d%% grown. Water %d%%, health %d%%.')
        :format(label, math.floor(condition.progress * 100), math.floor(condition.water), math.floor(condition.health))
end

--- Optional helper kept for compatibility.
function Target.Attach(entity, cropId)
    -- Slot sphere zones in slots.lua drive target interaction.
end

function Target.Detach(entity)
    -- Slot sphere zones in slots.lua drive target interaction.
end

--- Crop keys plantable in a zone, for the plant menu.
---@param zoneKey string
---@return string[]
function Target.AllowedCrops(zoneKey)
    return Sonar.Zones.AllowedCrops(zoneKey)
end
