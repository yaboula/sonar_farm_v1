--[[
    sonar_farm - Crop interaction (client)
    Exposes helper utilities and descriptors for crop target options.
    Slot sphere zones (in client/modules/zones/slots.lua) are the primary target
    entry-points for all slot interactions (Plant, Inspect, Water, Harvest).
]]

Target = Target or {}

local CROP_STATE = Sonar.Constants.CROP_STATE

local function dominantRisk(condition)
    return Sonar.Conditions.DominantDefect(condition):gsub('_', ' ')
end

local function advancedSummary(record, condition)
    if not Sonar.Conditions.IsAdvancedCareEnabled() then return '' end
    local parts = {}
    if Sonar.Conditions.IsEnabled(record, 'nutrients') then
        parts[#parts + 1] = ('nutrients %d%%'):format(math.floor(condition.nutrients or 0))
    end
    if Sonar.Conditions.IsEnabled(record, 'weeds') then
        parts[#parts + 1] = ('weeds %d%%'):format(math.floor(condition.weedCover or 0))
    end
    if Sonar.Conditions.IsEnabled(record, 'pests') then
        parts[#parts + 1] = ('pests %d%%'):format(math.floor(condition.pestPressure or 0))
    end
    local now = Sonar.Time.Now()
    if (condition.nutrientProtectionUntil or 0) > now then
        parts[#parts + 1] = ('%s nutrient protection %dm')
            :format(condition.nutrientProtectionTier or 'active', math.ceil((condition.nutrientProtectionUntil - now) / 60))
    end
    if (condition.pestProtectionUntil or 0) > now then
        parts[#parts + 1] = ('%s pest protection %dm')
            :format(condition.pestProtectionTier or 'active', math.ceil((condition.pestProtectionUntil - now) / 60))
    end
    return #parts > 0 and (' ' .. table.concat(parts, ', ') .. '.') or ''
end

--- Human-readable condition summary for the inspect option.
---@param cropId string
---@return string
function Target.Describe(cropId)
    local record = Crops.Get(cropId)
    local condition = Crops.Condition(cropId)
    if not record or not condition then return 'Unknown crop.' end

    local def = Config.Crops and Config.Crops[record.crop_type]
    local label = (def and def.label) or record.crop_type

    if condition.state == CROP_STATE.PLANTING or condition.state == CROP_STATE.PLANTING_FAILED then
        return ('%s: planting incomplete. Resume or clear this plot.'):format(label)
    end

    if condition.state == CROP_STATE.DEAD then
        return ('%s: dead. Harvest to clear the plot.'):format(label)
    end

    if condition.progress >= 1 then
        local risk = Sonar.Conditions.IsAdvancedCareEnabled()
            and (' Dominant defect risk: %s.'):format(dominantRisk(condition))
            or ''
        return ('%s: ready to harvest. Health %d%%.%s%s')
            :format(label, math.floor(condition.health), advancedSummary(record, condition), risk)
    end

    return ('%s: %d%% grown. Water %d%%, health %d%%.%s')
        :format(label, math.floor(condition.progress * 100), math.floor(condition.water),
            math.floor(condition.health), advancedSummary(record, condition))
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
