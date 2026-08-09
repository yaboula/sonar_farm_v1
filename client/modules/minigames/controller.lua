--[[
    sonar_farm - Planting NUI controller (client)

    Owns focus, ped state, local props and lifecycle monitoring. The browser is a
    renderer/input surface only: every checkpoint is forwarded to the server and
    the UI advances only after authoritative acceptance.
]]

Minigame = Minigame or {}

local CALLBACKS = Sonar.Constants.CALLBACKS
local NOTIFY = Sonar.Constants.NOTIFY

local active
local prop
local cancelling = false

local function nuiReply(callback, value)
    if callback then callback(value or { ok = true }) end
end

local function deleteProp()
    if prop and DoesEntityExist(prop) then
        DeleteEntity(prop)
    end
    prop = nil
end

local function attachTool(step)
    deleteProp()
    if not active then return end

    local modelName = step == 'water' and 'prop_wateringcan' or 'prop_tool_shovel'
    local model = joaat(modelName)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return end

    RequestModel(model)
    local deadline = GetGameTimer() + 1500
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) or not active then
        SetModelAsNoLongerNeeded(model)
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    if prop and prop ~= 0 then
        AttachEntityToEntity(
            prop,
            ped,
            GetPedBoneIndex(ped, 57005),
            0.12,
            0.02,
            -0.03,
            -80.0,
            15.0,
            10.0,
            true,
            true,
            false,
            true,
            1,
            true
        )
    end
    SetModelAsNoLongerNeeded(model)
end

local function releasePed()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    deleteProp()
end

local function closeUi(messageType, payload)
    if messageType then
        SendNUIMessage({ type = messageType, payload = payload })
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    releasePed()
    active = nil
    cancelling = false
end

local function preparePed(step)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    if not IsPedUsingScenario(ped, 'WORLD_HUMAN_GARDENER_PLANT') then
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GARDENER_PLANT', 0, true)
    end
    attachTool(step)
end

local function showSession(data, restore)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    active = {
        sessionId = data.sessionId,
        cropId = data.cropId,
        origin = { x = coords.x, y = coords.y, z = coords.z },
        initialHealth = GetEntityHealth(ped),
        nextStep = data.nextStep,
        contractVersion = data.contract and data.contract.contractVersion,
    }

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    preparePed(data.nextStep)
    SendNUIMessage({
        type = restore and 'tomatoPlant:restore' or 'tomatoPlant:open',
        payload = data,
    })
end

local function awaitServer(name, payload)
    local ok, result = pcall(lib.callback.await, name, false, payload)
    if not ok then
        Bridge.Log('error', ('Minigame callback failed: %s'):format(tostring(result)))
        return { ok = false, reason = Sonar.Constants.REJECT.INTERNAL_ERROR }
    end
    return result
end

local function checkpointTrace(data)
    local samples = type(data.trace) == 'table' and data.trace or {}
    local last = samples[#samples]
    local bucket = type(last) == 'table' and tonumber(last[1]) or 0
    return {
        durationMs = math.max(0, bucket or 0) * 50,
        samples = samples,
        signals = type(data.signals) == 'table' and data.signals or {},
    }
end

local function cancel(reason, notify)
    if not active or cancelling then return end
    cancelling = true
    local sessionId = active.sessionId

    CreateThread(function()
        awaitServer(CALLBACKS.MINIGAME_CANCEL, {
            sessionId = sessionId,
            reason = reason or 'cancelled',
        })
        closeUi('tomatoPlant:close', { reason = reason })
        Sync.RefreshNow()
        if notify then Bridge.Notify(notify, NOTIFY.ERROR) end
    end)
end

---@param cropType string
---@param zoneKey string
---@param slotIndex number
function Minigame.Begin(cropType, zoneKey, slotIndex)
    if active then
        return Bridge.Notify('A planting session is already open.', NOTIFY.ERROR)
    end
    if Hub and Hub.IsActive and Hub.IsActive() then
        return Bridge.Notify('Close the Business Hub before planting.', NOTIFY.ERROR)
    end
    if Inspection and Inspection.IsActive and Inspection.IsActive() then Inspection.Close('minigame_open') end

    local response = awaitServer(CALLBACKS.MINIGAME_BEGIN, {
        cropType = cropType,
        zone = zoneKey,
        slot = slotIndex,
    })
    if not response or not response.ok then
        return Actions.HandleRejection(response)
    end

    showSession(response.data, response.restore == true)
end

---@param cropId string
function Minigame.Resume(cropId)
    if active or Hub and Hub.IsActive and Hub.IsActive() then return end
    if Inspection and Inspection.IsActive and Inspection.IsActive() then Inspection.Close('minigame_open') end
    local response = awaitServer(CALLBACKS.MINIGAME_RESUME, { cropId = cropId })
    if not response or not response.ok then
        return Actions.HandleRejection(response)
    end
    showSession(response.data, true)
end

---@param cropId string
function Minigame.ClearIncomplete(cropId)
    local response = awaitServer(CALLBACKS.MINIGAME_CLEAR_INCOMPLETE, { cropId = cropId })
    if not response or not response.ok then
        return Actions.HandleRejection(response)
    end
    Sync.RefreshNow()
    Bridge.Notify('Incomplete planting cleared.', NOTIFY.SUCCESS)
end

function Minigame.IsActive()
    return active ~= nil
end

RegisterNUICallback('tomatoPlant:ready', function(_, callback)
    nuiReply(callback, { ok = true, active = active ~= nil })
end)

RegisterNUICallback('tomatoPlant:checkpoint', function(data, callback)
    if not active or type(data) ~= 'table' then
        return nuiReply(callback, {
            ok = false,
            reason = Sonar.Constants.REJECT.MINIGAME_SESSION_NOT_FOUND,
        })
    end
    if tostring(data.contractVersion) ~= tostring(active.contractVersion) then
        return nuiReply(callback, {
            ok = false,
            reason = Sonar.Constants.REJECT.MINIGAME_INVALID_TRACE,
            detail = 'contract_version',
        })
    end

    local response = awaitServer(CALLBACKS.MINIGAME_CHECKPOINT, {
        sessionId = active.sessionId,
        contractVersion = active.contractVersion,
        step = data.step,
        trace = checkpointTrace(data),
    })
    nuiReply(callback, response)

    if not response or not response.ok then
        if response and (response.reason == Sonar.Constants.REJECT.TOO_FAR
            or response.reason == Sonar.Constants.REJECT.MINIGAME_SESSION_EXPIRED) then
            closeUi('tomatoPlant:close', response)
            Sync.RefreshNow()
        end
        return
    end

    if response.complete then
        local result = response.data
        deleteProp()
        SetNuiFocus(true, true)
        active.completed = true
        active.result = result
        Sync.RefreshNow()
        return
    end

    active.nextStep = response.data.nextStep
    attachTool(active.nextStep)
end)

RegisterNUICallback('tomatoPlant:cancel', function(data, callback)
    nuiReply(callback)
    cancel(type(data) == 'table' and data.reason or 'escape')
end)

RegisterNUICallback('tomatoPlant:close', function(_, callback)
    nuiReply(callback)
    if active and not active.completed then
        cancel('ui_closed')
        return
    end
    closeUi()
end)

RegisterNUICallback('tomatoPlant:error', function(data, callback)
    local message = type(data) == 'table' and tostring(data.error or data.callbackName) or 'unknown'
    Bridge.Log('error', ('Planting NUI reported an error: %s'):format(message))
    nuiReply(callback)
end)

-- Death, meaningful damage, or an external teleport invalidates the interaction.
CreateThread(function()
    while true do
        if not active or active.completed then
            Wait(500)
        else
            Wait(100)
            local ped = PlayerPedId()
            local health = GetEntityHealth(ped)
            if IsEntityDead(ped) or health <= 0 then
                cancel('death', 'Planting interrupted.')
            elseif active.initialHealth - health >= (Config.Farming.MinigameDamageThreshold or 15) then
                cancel('damage', 'Planting interrupted by damage.')
            else
                local coords = GetEntityCoords(ped)
                if Sonar.Utils.Distance(coords, active.origin) > Config.Security.MaxInteractDistance then
                    cancel('moved_too_far', 'You moved too far from the plot.')
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    releasePed()
end)

