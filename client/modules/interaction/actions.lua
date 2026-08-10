--[[
    sonar_farm - Player actions (client)
    The single place where the client asks the server to do something. Everything
    else (target options, item use, debug commands) routes through here, so the
    rejection handling and resync logic exist once.

    Planting always targets a configured slot. The client never invents
    coordinates: it only sends zone + slot index, and the server places the crop
    at the slot defined in config.
]]

Actions = Actions or {}

local CALLBACKS = Sonar.Constants.CALLBACKS
local ACTIONS = Sonar.Constants.ACTIONS
local REJECT = Sonar.Constants.REJECT
local NOTIFY = Sonar.Constants.NOTIFY

-- PLACEHOLDER durations (ms). Stage 5 replaces every one of these with a real
-- minigame, so they are deliberately kept out of config: there is nothing here
-- worth tuning before it gets deleted.
local PLACEHOLDER_DURATION = {
    plant = 2500,
    water = 2000,
    harvest = 3000,
    fertilize = 2200,
    weed = 2500,
    treat_pest = 2200,
}

local MESSAGES = {
    [REJECT.RATE_LIMITED] = 'Slow down.',
    [REJECT.SERVICE_UNAVAILABLE] = 'Farming is still starting. Try again shortly.',
    [REJECT.PLAYER_NOT_READY] = 'Your character is still loading.',
    [REJECT.WRONG_INSTANCE] = 'Farming is not available in this instance.',
    [REJECT.COOLDOWN] = 'Please wait a moment.',
    [REJECT.TOO_FAR] = 'You are too far away.',
    [REJECT.SUSPICIOUS_MOVEMENT] = 'Movement validation failed.',
    [REJECT.NOT_IN_ZONE] = 'You are not inside a farming zone.',
    [REJECT.CROP_NOT_ALLOWED_HERE] = 'That crop cannot be planted in this zone.',
    [REJECT.SLOT_NOT_FOUND] = 'That planting plot does not exist.',
    [REJECT.SLOT_OCCUPIED] = 'Something is already growing there.',
    [REJECT.UNKNOWN_CROP] = 'Unknown crop type.',
    [REJECT.MISSING_SEED] = 'You do not have the required planting stock.',
    [REJECT.MISSING_TOOL] = 'You do not have the required tool or treatment.',
    [REJECT.CROP_NOT_FOUND] = 'That crop is no longer there.',
    [REJECT.CROP_NOT_MATURE] = 'This crop is not ready to harvest.',
    [REJECT.CROP_DEAD] = 'This crop is dead.',
    [REJECT.NOT_OWNER] = 'This crop belongs to someone else.',
    [REJECT.CROP_LIMIT_REACHED] = 'You have reached your active crop limit.',
    [REJECT.INVENTORY_FULL] = 'Your inventory is full.',
    [REJECT.ALREADY_IN_PROGRESS] = 'Someone is already working on this plot.',
    [REJECT.ALREADY_WATERED] = 'This crop does not need water yet.',
    [REJECT.NUTRIENTS_SATURATED] = 'This crop cannot absorb more nutrients.',
    [REJECT.NO_WEEDS_DETECTED] = 'There are not enough weeds to remove.',
    [REJECT.NO_PEST_DETECTED] = 'No meaningful pest pressure was detected.',
    [REJECT.CONDITION_DISABLED] = 'That crop condition is not enabled.',
    [REJECT.MINIGAME_REQUIRED] = 'This crop must be planted by hand.',
    [REJECT.MINIGAME_DISABLED] = 'Planting practice is temporarily unavailable.',
    [REJECT.MINIGAME_SESSION_NOT_FOUND] = 'That planting session is no longer active.',
    [REJECT.MINIGAME_SESSION_EXPIRED] = 'The planting session expired. You can resume the plot.',
    [REJECT.MINIGAME_INVALID_STEP] = 'That planting step arrived out of order.',
    [REJECT.MINIGAME_INVALID_TRACE] = 'The planting input could not be verified.',
    [REJECT.PLANTING_INCOMPLETE] = 'This planting is incomplete.',
    [REJECT.INTERNAL_ERROR] = 'Something went wrong.',
}

-- Rejections that mean our local cache disagrees with the server. Each one is a
-- free desync signal, so we use it to self-correct instead of just complaining.
local STALE_CACHE_REASONS = {
    [REJECT.CROP_NOT_FOUND] = true,
    [REJECT.CROP_NOT_MATURE] = true,
    [REJECT.CROP_DEAD] = true,
    [REJECT.ALREADY_WATERED] = true,
    [REJECT.NUTRIENTS_SATURATED] = true,
    [REJECT.NO_WEEDS_DETECTED] = true,
    [REJECT.NO_PEST_DETECTED] = true,
    [REJECT.SLOT_OCCUPIED] = true,
}

-- Seed item -> crop type, built once from the crop definitions.
local seedToCrop = {}
for cropType, def in pairs(Config.Crops or {}) do
    if def.seedItem then
        seedToCrop[def.seedItem] = cropType
    end
    if def.legacySeedItem then
        seedToCrop[def.legacySeedItem] = cropType
    end
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---@param response table|nil
local function handleRejection(response)
    local reason = response and response.reason

    Bridge.Notify(MESSAGES[reason] or ('Action failed (%s).'):format(tostring(reason)), NOTIFY.ERROR)

    if reason and STALE_CACHE_REASONS[reason] then
        Sync.RefreshNow()
    end
end

Actions.HandleRejection = handleRejection

--- PLACEHOLDER progress feedback. Without any delay the action feels unfinished
--- and the gameplay cannot be judged; with a pretty bar we would be building
--- Stage 6 twice. Intentionally plain and temporary.
---@param label string
---@param action string
---@return boolean completed
local function placeholderProgress(label, action)
    return lib.progressCircle({
        duration = PLACEHOLDER_DURATION[action] or 2000,
        label = label,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, combat = true },
    })
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

--- Plant a crop into a configured slot.
---@param cropType string
---@param zoneKey string
---@param slotIndex number
function Actions.Plant(cropType, zoneKey, slotIndex)
    if Inspection and Inspection.IsActive() then Inspection.Close('action') end
    local def = Config.Crops and Config.Crops[cropType]
    if not def then
        return Bridge.Notify(MESSAGES[REJECT.UNKNOWN_CROP], NOTIFY.ERROR)
    end

    if type(zoneKey) ~= 'string' or not tonumber(slotIndex) then
        return Bridge.Notify(MESSAGES[REJECT.SLOT_NOT_FOUND], NOTIFY.ERROR)
    end

    if Config.Features.Minigames and def.requiresMinigame then
        return Minigame.Begin(cropType, zoneKey, tonumber(slotIndex))
    end

    if not placeholderProgress(('Planting %s...'):format(def.label), 'plant') then
        return
    end

    local response = lib.callback.await(CALLBACKS.PLANT, false, {
        cropType = cropType,
        zone = zoneKey,
        slot = tonumber(slotIndex),
    })

    if not response or not response.ok then
        return handleRejection(response)
    end

    Bridge.Notify(('Planted %s.'):format(response.data.label), NOTIFY.SUCCESS)

    -- The server already pushed the delta; refresh so the prop shows up and the
    -- empty-slot option disappears immediately.
    Crops.Refresh(GetEntityCoords(PlayerPedId()))
    Slots.RefreshProps()
end

--- Water a crop.
---@param cropId string
function Actions.Water(cropId, itemId)
    if not cropId then return end

    if not placeholderProgress('Watering...', 'water') then
        return
    end

    local response = lib.callback.await(CALLBACKS.WATER, false, { cropId = cropId, itemId = itemId })
    if not response or not response.ok then
        return handleRejection(response)
    end

    Bridge.Notify(('Watered. Water %s%%, health %s%%.')
        :format(response.data.water, response.data.health), NOTIFY.SUCCESS)
    if response.data.toolBroken then Bridge.Notify('The tool reached the end of its service life.', NOTIFY.WARNING) end
end

function Actions.Fertilize(cropId, itemId)
    if not cropId or not placeholderProgress('Fertilizing...', 'fertilize') then return end
    local response = lib.callback.await(CALLBACKS.FERTILIZE, false, { cropId = cropId, itemId = itemId })
    if not response or not response.ok then return handleRejection(response) end
    Bridge.Notify(('Fertilized. Nutrients %s%%.'):format(response.data.nutrients), NOTIFY.SUCCESS)
end

function Actions.Weed(cropId, itemId)
    if not cropId or not placeholderProgress('Removing weeds...', 'weed') then return end
    local response = lib.callback.await(CALLBACKS.WEED, false, { cropId = cropId, itemId = itemId })
    if not response or not response.ok then return handleRejection(response) end
    Bridge.Notify(('Weeded. Cover %s%%.'):format(response.data.weedCover), NOTIFY.SUCCESS)
    if response.data.toolBroken then Bridge.Notify('The tool reached the end of its service life.', NOTIFY.WARNING) end
end

function Actions.TreatPests(cropId, itemId)
    if not cropId or not placeholderProgress('Treating pests...', 'treat_pest') then return end
    local response = lib.callback.await(CALLBACKS.TREAT_PEST, false, { cropId = cropId, itemId = itemId })
    if not response or not response.ok then return handleRejection(response) end
    Bridge.Notify(('Treated. Pest pressure %s%%.'):format(response.data.pestPressure), NOTIFY.SUCCESS)
end

local CARE_ACTION = {
    water = Actions.Water,
    fertilize = Actions.Fertilize,
    weed = Actions.Weed,
    treat_pest = Actions.TreatPests,
}

local CARE_ICON = {
    water = 'droplet',
    fertilize = 'flask',
    weed = 'leaf',
    treat_pest = 'bug',
}

local function protectionLabel(option)
    local effect = option.effect or {}
    local ratio = math.max(0, tonumber(option.protectionCycleRatio or effect.protectionCycleRatio) or 0)
    local seconds = math.max(0, tonumber(option.protectionSeconds) or 0)
    if ratio <= 0 and seconds <= 0 then return '' end
    local minutes = math.max(1, math.floor(seconds / 60 + 0.5))
    if ratio > 0 then
        return (' | %d%% cycle (%dm here)'):format(math.floor(ratio * 100 + 0.5), minutes)
    end
    return (' | %dm retention'):format(minutes)
end

local function careDescription(action, option)
    local effect = option.effect or {}
    local protection = protectionLabel(option)
    if action == ACTIONS.WATER then
        return ('%s tier | +%d water%s | %d uses remaining'):format(option.tier,
            effect.amount or 100, protection,
            option.usesRemaining or 0)
    elseif action == ACTIONS.WEED then
        return ('%s tier | removes %d%%%s | %d uses remaining')
            :format(option.tier, effect.weedRemoval or 0,
                protection, option.usesRemaining or 0)
    elseif action == ACTIONS.FERTILIZE then
        return ('%s tier | +%d nutrients | %d%% retention%s | %d available')
            :format(option.tier, effect.amount or 0, math.floor((effect.protectionStrength or 0) * 100),
                protection, option.count or 0)
    end
    return ('%s tier | -%d pressure | %d%% suppression%s | %d available')
        :format(option.tier, effect.reduction or 0, math.floor((effect.protectionStrength or 0) * 100),
            protection, option.count or 0)
end

function Actions.OpenCareMenu(action, cropId)
    if Inspection and Inspection.IsActive() then Inspection.Close('action') end
    local execute = CARE_ACTION[action]
    if not execute or not cropId then return end
    local response = lib.callback.await(CALLBACKS.CARE_OPTIONS, false, { cropId = cropId, action = action })
    if not response or not response.ok then return handleRejection(response) end
    local available = response.data and response.data.options or {}
    if #available == 0 then
        return Bridge.Notify('You do not have an eligible tool or treatment.', NOTIFY.ERROR)
    end
    local options = {}
    for _, option in ipairs(available) do
        local selected = option
        options[#options + 1] = {
            title = selected.label,
            description = careDescription(action, selected),
            icon = CARE_ICON[action],
            onSelect = function() execute(cropId, selected.id) end,
        }
    end
    lib.registerContext({ id = 'sonar_farm_care_' .. action, title = 'Select field material', options = options })
    lib.showContext('sonar_farm_care_' .. action)
end

--- Harvest a crop.
---@param cropId string
function Actions.Harvest(cropId)
    if Inspection and Inspection.IsActive() then Inspection.Close('action') end
    if not cropId then return end

    if not placeholderProgress('Harvesting...', 'harvest') then
        return
    end

    local response = lib.callback.await(CALLBACKS.HARVEST, false, { cropId = cropId })
    if not response or not response.ok then
        return handleRejection(response)
    end

    local data = response.data
    local detail = Config.Features.AdvancedCare
        and (', production %s, defect %s'):format(data.productionScore, data.defect)
        or ''
    Bridge.Notify(('Harvested %d x %s (%s, quality %s%s).')
        :format(data.units, data.cropType, data.tierLabel, data.quality, detail), NOTIFY.SUCCESS)

    Slots.RefreshProps()
end

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

--- Context menu of seeds plantable in a specific empty slot.
---@param zoneKey string
---@param slotIndex number
function Actions.OpenPlantMenu(zoneKey, slotIndex)
    if Inspection and Inspection.IsActive() then Inspection.Close('action') end
    if Crops.IsSlotOccupied(zoneKey, slotIndex) then
        return Bridge.Notify(MESSAGES[REJECT.SLOT_OCCUPIED], NOTIFY.ERROR)
    end

    local options = {}

    for _, cropType in ipairs(Target.AllowedCrops(zoneKey)) do
        local def = Config.Crops[cropType]
        if def then
            local primaryCount = def.seedItem and Bridge.Inventory.GetItemCount(def.seedItem) or 0
            local legacyCount = def.legacySeedItem and Bridge.Inventory.GetItemCount(def.legacySeedItem) or 0
            local held = primaryCount + legacyCount
            options[#options + 1] = {
                title = def.label,
                description = ('Planting stock: %d  |  Grows in %d min'):format(held, math.floor((def.growthTime or 0) / 60)),
                icon = 'seedling',
                disabled = held < 1,
                onSelect = function()
                    Actions.Plant(cropType, zoneKey, slotIndex)
                end,
            }
        end
    end

    if #options == 0 then
        return Bridge.Notify('Nothing can be planted in this plot.', NOTIFY.ERROR)
    end

    lib.registerContext({
        id = 'sonar_farm_plant',
        title = 'Plant crop',
        options = options,
    })
    lib.showContext('sonar_farm_plant')
end

--- ox_inventory item use. Does not free-plant: it finds the nearest empty slot
--- and plants that seed into it. No empty plot nearby = clear feedback, not a
--- crop growing wherever the player happened to stand.
---@param data table ox_inventory item data (needs `name`)
function Actions.UseSeed(data)
    local cropType = data and seedToCrop[data.name]
    if not cropType then
        return Bridge.Notify(MESSAGES[REJECT.UNKNOWN_CROP], NOTIFY.ERROR)
    end

    local slot = Slots.NearestEmpty(GetEntityCoords(PlayerPedId()))
    if not slot then
        return Bridge.Notify('Stand next to an empty planting plot.', NOTIFY.ERROR)
    end

    if not Sonar.Zones.AllowsCrop(slot.zone, cropType) then
        return Bridge.Notify(MESSAGES[REJECT.CROP_NOT_ALLOWED_HERE], NOTIFY.ERROR)
    end

    Actions.Plant(cropType, slot.zone, slot.index)
end

exports('useSeed', function(data)
    Actions.UseSeed(data)
end)
