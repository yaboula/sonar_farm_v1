--[[
    sonar_farm - Player actions (client)
    The single place where the client asks the server to do something. Everything
    else (target options, item use, debug commands) routes through here, so the
    rejection handling and resync logic exist once.

    Rejection codes are turned into text here rather than on the server: the
    server stays language-agnostic and player-facing wording lives in the
    presentation layer.
]]

Actions = Actions or {}

local CALLBACKS = Sonar.Constants.CALLBACKS
local REJECT = Sonar.Constants.REJECT
local NOTIFY = Sonar.Constants.NOTIFY

-- PLACEHOLDER durations (ms). Stage 5 replaces every one of these with a real
-- minigame, so they are deliberately kept out of config: there is nothing here
-- worth tuning before it gets deleted.
local PLACEHOLDER_DURATION = {
    plant = 2500,
    water = 2000,
    harvest = 3000,
}

local MESSAGES = {
    [REJECT.RATE_LIMITED] = 'Slow down.',
    [REJECT.COOLDOWN] = 'Please wait a moment.',
    [REJECT.TOO_FAR] = 'You are too far away.',
    [REJECT.SUSPICIOUS_MOVEMENT] = 'Movement validation failed.',
    [REJECT.NOT_IN_ZONE] = 'You are not inside a farming zone.',
    [REJECT.CROP_NOT_ALLOWED_HERE] = 'That crop cannot be planted in this zone.',
    [REJECT.UNKNOWN_CROP] = 'Unknown crop type.',
    [REJECT.MISSING_SEED] = 'You do not have the required seeds.',
    [REJECT.MISSING_TOOL] = 'You need a watering can.',
    [REJECT.CROP_NOT_FOUND] = 'That crop is no longer there.',
    [REJECT.CROP_NOT_MATURE] = 'This crop is not ready to harvest.',
    [REJECT.CROP_DEAD] = 'This crop is dead.',
    [REJECT.NOT_OWNER] = 'This crop belongs to someone else.',
    [REJECT.CROP_LIMIT_REACHED] = 'You have reached your active crop limit.',
    [REJECT.INVENTORY_FULL] = 'Your inventory is full.',
    [REJECT.ALREADY_IN_PROGRESS] = 'Someone is already working on this crop.',
    [REJECT.ALREADY_WATERED] = 'This crop does not need water yet.',
    [REJECT.INTERNAL_ERROR] = 'Something went wrong.',
}

-- Rejections that mean our local cache disagrees with the server. Each one is a
-- free desync signal, so we use it to self-correct instead of just complaining.
local STALE_CACHE_REASONS = {
    [REJECT.CROP_NOT_FOUND] = true,
    [REJECT.CROP_NOT_MATURE] = true,
    [REJECT.CROP_DEAD] = true,
    [REJECT.ALREADY_WATERED] = true,
}

-- Seed item -> crop type, built once from the crop definitions.
local seedToCrop = {}
for cropType, def in pairs(Config.Crops or {}) do
    if def.seedItem then
        seedToCrop[def.seedItem] = cropType
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

--- Plant a crop at the player's current position.
---@param cropType string
function Actions.Plant(cropType)
    local def = Config.Crops and Config.Crops[cropType]
    if not def then
        return Bridge.Notify(MESSAGES[REJECT.UNKNOWN_CROP], NOTIFY.ERROR)
    end

    if not placeholderProgress(('Planting %s...'):format(def.label), 'plant') then
        return
    end

    local response = lib.callback.await(CALLBACKS.PLANT, false, { cropType = cropType })
    if not response or not response.ok then
        return handleRejection(response)
    end

    Bridge.Notify(('Planted %s.'):format(response.data.label), NOTIFY.SUCCESS)

    -- The server already pushed the delta to our cell; refresh so the prop shows
    -- up immediately instead of on the next tick.
    Crops.Refresh(GetEntityCoords(PlayerPedId()))
end

--- Water a crop.
---@param cropId string
function Actions.Water(cropId)
    if not cropId then return end

    if not placeholderProgress('Watering...', 'water') then
        return
    end

    local response = lib.callback.await(CALLBACKS.WATER, false, { cropId = cropId })
    if not response or not response.ok then
        return handleRejection(response)
    end

    Bridge.Notify(('Watered. Water %s%%, health %s%%.')
        :format(response.data.water, response.data.health), NOTIFY.SUCCESS)
end

--- Harvest a crop.
---@param cropId string
function Actions.Harvest(cropId)
    if not cropId then return end

    if not placeholderProgress('Harvesting...', 'harvest') then
        return
    end

    local response = lib.callback.await(CALLBACKS.HARVEST, false, { cropId = cropId })
    if not response or not response.ok then
        return handleRejection(response)
    end

    local data = response.data
    Bridge.Notify(('Harvested %d x %s (%s, quality %s).')
        :format(data.units, data.cropType, data.tierLabel, data.quality), NOTIFY.SUCCESS)
end

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

--- Context menu listing what can be planted in a zone, with the seeds the player
--- is actually carrying.
---@param zoneKey string
function Actions.OpenPlantMenu(zoneKey)
    local options = {}

    for _, cropType in ipairs(Target.AllowedCrops(zoneKey)) do
        local def = Config.Crops[cropType]
        if def then
            local held = Bridge.Inventory.GetItemCount(def.seedItem) or 0
            options[#options + 1] = {
                title = def.label,
                description = ('Seeds: %d  |  Grows in %d min'):format(held, math.floor((def.growthTime or 0) / 60)),
                icon = 'seedling',
                disabled = held < 1,
                onSelect = function()
                    Actions.Plant(cropType)
                end,
            }
        end
    end

    if #options == 0 then
        return Bridge.Notify('Nothing can be planted here.', NOTIFY.ERROR)
    end

    lib.registerContext({
        id = 'sonar_farm_plant',
        title = 'Plant seeds',
        options = options,
    })
    lib.showContext('sonar_farm_plant')
end

--- ox_inventory item use: planting by using the seed, which is what players try
--- first. Wired through `client.export` in data/ox_inventory_items.lua.
---@param data table ox_inventory item data (needs `name`)
function Actions.UseSeed(data)
    local cropType = data and seedToCrop[data.name]
    if not cropType then
        return Bridge.Notify(MESSAGES[REJECT.UNKNOWN_CROP], NOTIFY.ERROR)
    end
    Actions.Plant(cropType)
end

exports('useSeed', function(data)
    Actions.UseSeed(data)
end)
