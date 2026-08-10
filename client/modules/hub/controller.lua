-- Business Hub NUI lifecycle and generic runtime bridge.

Hub = Hub or {}
local CALLBACKS = Sonar.Constants.CALLBACKS
local active
local zones = {}

local function reply(callback, value) if callback then callback(value or { ok = true }) end end

function Hub.Close()
    if active then lib.callback.await(CALLBACKS.HUB_CLOSE, false, { nonce = active.nonce }) end
    active = nil
    SendNUIMessage({ type = 'hub:close' })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

function Hub.Open(surface, presence)
    if active or Minigame.IsActive() then return end
    if Inspection and Inspection.IsActive() then Inspection.Close('hub_open') end
    local response = lib.callback.await(CALLBACKS.HUB_OPEN, false, { surface = surface, presence = presence })
    if not response or not response.ok then
        return Bridge.Notify(response and response.reason == 'permission_denied' and 'No Company or Contract access is available.' or 'The Business Hub is unavailable.', 'error')
    end
    active = response.data
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'hub:open', payload = active })
end

function Hub.IsActive()
    return active ~= nil
end

RegisterNUICallback('hub:bootstrap', function(_, callback)
    reply(callback, active and { ok = true, data = active } or { ok = false, reason = 'invalid_session' })
end)

RegisterNUICallback('hub:load', function(data, callback)
    if not active then return reply(callback, { ok = false, reason = 'invalid_session' }) end
    reply(callback, lib.callback.await(CALLBACKS.HUB_LOAD, false, { nonce = active.nonce, request = data and data.request }))
end)

RegisterNUICallback('hub:dispatch', function(data, callback)
    if not active then return reply(callback, { ok = false, reason = 'invalid_session' }) end
    local response = lib.callback.await(CALLBACKS.HUB_DISPATCH, false, { nonce = active.nonce, intent = data and data.intent })
    if response and response.route then SetNewWaypoint(response.route.x + 0.0, response.route.y + 0.0) end
    reply(callback, response)
    if response and response.closeSurface then Hub.Close() end
end)

RegisterNUICallback('hub:subscribeField', function(data, callback)
    if not active then return reply(callback, { ok = false, reason = 'invalid_session' }) end
    reply(callback, lib.callback.await(CALLBACKS.HUB_SUBSCRIBE_FIELD, false, {
        nonce = active.nonce, fieldId = data and data.fieldId, afterSequence = data and data.afterSequence,
    }))
end)

RegisterNUICallback('hub:unsubscribeField', function(_, callback)
    if active then lib.callback.await(CALLBACKS.HUB_SUBSCRIBE_FIELD, false, { nonce = active.nonce, fieldId = '' }) end
    reply(callback, { ok = true })
end)

RegisterNetEvent(Sonar.Constants.EVENTS.FIELD_DELTA, function(delta)
    if active then SendNUIMessage({ type = 'hub:fieldDelta', payload = delta }) end
end)

RegisterNUICallback('hub:close', function(_, callback) reply(callback); Hub.Close() end)

if Config.Features.Supplies or Config.Features.Fields then
    RegisterCommand(Config.Supplies.TabletCommand, function() Hub.Open('tablet', 'remote') end, false)
    RegisterKeyMapping(Config.Supplies.TabletCommand, 'Open Sonar Farm Tablet', 'keyboard', Config.Supplies.TabletKey)

    CreateThread(function()
        zones.office = Bridge.Target.AddSphereZone({ coords = Config.Supplies.Office.coords, radius = Config.Supplies.Office.radius,
            options = {{ name = 'sonar_farm:office', label = 'Open Farm Office', icon = 'fa-solid fa-building', onSelect = function() Hub.Open('office', 'office') end }} })
        zones.warehouse = Bridge.Target.AddSphereZone({ coords = Config.Supplies.Warehouse.coords, radius = Config.Supplies.Warehouse.radius,
            options = {{ name = 'sonar_farm:warehouse', label = 'Open Company Warehouse', icon = 'fa-solid fa-warehouse', onSelect = function() Hub.Open('office', 'warehouse') end }} })
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, zone in pairs(zones) do Bridge.Target.RemoveZone(zone) end
    if active then Hub.Close() end
end)
