--[[
    sonar_farm - Client test commands (Stage 3)
    Temporary entry point until ox_target interaction lands in Stage 4. The
    client only sends intent and renders the server's answer: it never computes
    yield, quality or eligibility.

    Registered only when Config.Debug is true.
]]

if not Config.Debug then return end

local CALLBACKS = Sonar.Constants.CALLBACKS
local REJECT = Sonar.Constants.REJECT
local NOTIFY = Sonar.Constants.NOTIFY

-- Presentation layer: the server returns machine-readable reason codes and the
-- client turns them into text. Keeps player-facing wording out of the server.
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
    [REJECT.CROP_NOT_FOUND] = 'Crop not found.',
    [REJECT.CROP_NOT_MATURE] = 'This crop is not ready to harvest.',
    [REJECT.CROP_DEAD] = 'This crop is dead.',
    [REJECT.NOT_OWNER] = 'This crop belongs to someone else.',
    [REJECT.CROP_LIMIT_REACHED] = 'You have reached your active crop limit.',
    [REJECT.INVENTORY_FULL] = 'Your inventory is full.',
    [REJECT.ALREADY_IN_PROGRESS] = 'Someone is already working on this crop.',
    [REJECT.ALREADY_WATERED] = 'This crop does not need water yet.',
    [REJECT.INTERNAL_ERROR] = 'Something went wrong.',
}

local function notifyRejection(response)
    local reason = response and response.reason
    Bridge.Notify(MESSAGES[reason] or ('Action failed (%s).'):format(tostring(reason)), NOTIFY.ERROR)
end

--- Resolve a crop id: use the one provided, otherwise pick the closest nearby.
---@param provided string|nil
---@return string|nil cropId
local function resolveCropId(provided)
    if provided and provided ~= '' then return provided end

    local nearby = lib.callback.await(CALLBACKS.NEARBY, false, 20.0)
    if not nearby or #nearby == 0 then return nil end

    local closest = nearby[1]
    for _, crop in ipairs(nearby) do
        if crop.distance < closest.distance then closest = crop end
    end
    return closest.cropId
end

RegisterCommand('farm_plant', function(_, args)
    local cropType = args[1] or 'carrot'

    local response = lib.callback.await(CALLBACKS.PLANT, false, { cropType = cropType })
    if not response or not response.ok then
        return notifyRejection(response)
    end

    Bridge.Notify(('Planted %s in %s.'):format(response.data.label, response.data.zone), NOTIFY.SUCCESS)
    print(('[sonar_farm] planted cropId=%s'):format(response.data.cropId))
end, false)

RegisterCommand('farm_water', function(_, args)
    local cropId = resolveCropId(args[1])
    if not cropId then
        return Bridge.Notify('No crop nearby.', NOTIFY.ERROR)
    end

    local response = lib.callback.await(CALLBACKS.WATER, false, { cropId = cropId })
    if not response or not response.ok then
        return notifyRejection(response)
    end

    Bridge.Notify(('Watered. Water %s%%, health %s%%.')
        :format(response.data.water, response.data.health), NOTIFY.SUCCESS)
end, false)

RegisterCommand('farm_harvest', function(_, args)
    local cropId = resolveCropId(args[1])
    if not cropId then
        return Bridge.Notify('No crop nearby.', NOTIFY.ERROR)
    end

    local response = lib.callback.await(CALLBACKS.HARVEST, false, { cropId = cropId })
    if not response or not response.ok then
        return notifyRejection(response)
    end

    local data = response.data
    Bridge.Notify(('Harvested %d x %s (%s, quality %s).')
        :format(data.units, data.cropType, data.tierLabel, data.quality), NOTIFY.SUCCESS)
end, false)

RegisterCommand('farm_near', function(_, args)
    local radius = tonumber(args[1]) or 20.0
    local nearby = lib.callback.await(CALLBACKS.NEARBY, false, radius)

    if not nearby or #nearby == 0 then
        return Bridge.Notify('No crops nearby.', NOTIFY.INFO)
    end

    Bridge.Notify(('%d crop(s) nearby. See F8 console.'):format(#nearby), NOTIFY.INFO)
    for _, crop in ipairs(nearby) do
        print(('[sonar_farm] %s | %s | %.1fm | %s | growth %s%% | water %s%% | health %s%%')
            :format(crop.cropId, crop.cropType, crop.distance, crop.state,
                crop.progress, crop.water, crop.health))
    end
end, false)
