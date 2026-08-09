-- Focus-free crop inspection HUD lifecycle.

Inspection = Inspection or {}

local CALLBACKS = Sonar.Constants.CALLBACKS
local active
local loopRunning = false
local forceSeries = false

local function layoutInsets()
    local width = select(1, GetActiveScreenResolution())
    local cfg = Config.Inspection or {}
    local safeZone = GetSafeZoneSize()
    local safePad = math.max(0, (1 - safeZone) * 0.5 * width)
    return {
        leftInset = math.floor(safePad + width * (tonumber(cfg.MinimapWidthRatio) or 0.168)
            + (tonumber(cfg.MinimapGapPixels) or 18)),
        rightInset = math.floor(safePad + (tonumber(cfg.RightInsetPixels) or 18)),
    }
end

local function send(messageType, payload)
    SendNUIMessage({ type = messageType, payload = payload })
end

function Inspection.Close(reason)
    if not active then return end
    active = nil
    forceSeries = false
    send('inspection:close', { reason = reason or 'closed' })
end

local function validContext(record)
    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return false end
    local coords = GetEntityCoords(ped)
    return Sonar.Utils.Distance(coords, {
        x = record.pos_x,
        y = record.pos_y,
        z = record.pos_z,
    }) <= (tonumber(Config.Inspection and Config.Inspection.CloseDistance) or 4.0)
end

local function publish(messageType, includeSeries)
    if not active then return false end
    local record = Crops.Get(active.cropId)
    if not record or not validContext(record) then
        Inspection.Close(record and 'distance' or 'crop_removed')
        return false
    end
    local payload = Sonar.Inspection.Build(record, Sonar.Time.Now(), { includeSeries = includeSeries })
    payload.layout = layoutInsets()
    send(messageType, payload)
    return true
end

local function ensureLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        local lastSeriesAt = 0
        while active do
            local now = GetGameTimer()
            local curveEvery = math.max(1, tonumber(Config.Inspection and Config.Inspection.CurveRefreshSeconds) or 5) * 1000
            local rebuild = forceSeries or now - lastSeriesAt >= curveEvery
            forceSeries = false
            if publish('inspection:update', rebuild) and rebuild then lastSeriesAt = now end
            if IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 177) then
                Inspection.Close('manual')
                break
            end
            Wait(math.max(250, (tonumber(Config.Inspection and Config.Inspection.ValueRefreshSeconds) or 1) * 1000))
        end
        loopRunning = false
    end)
end

function Inspection.Open(cropId)
    if not Config.Features.InspectionHud then
        return Bridge.Notify(Target.Describe(cropId), Sonar.Constants.NOTIFY.INFO)
    end
    if active and active.cropId == cropId then
        return Inspection.Close('toggle')
    end
    if (Hub and Hub.IsActive and Hub.IsActive()) or (Minigame and Minigame.IsActive and Minigame.IsActive()) then
        return
    end

    local response = lib.callback.await(CALLBACKS.INSPECT, false, { cropId = cropId })
    if not response or not response.ok then
        return Bridge.Notify('Crop inspection is unavailable.', Sonar.Constants.NOTIFY.ERROR)
    end
    Sonar.Time.Sync(response.serverTime)
    Crops.Upsert(response.crop)
    active = { cropId = cropId }
    forceSeries = false
    publish('inspection:open', true)
    ensureLoop()
end

function Inspection.Toggle(cropId)
    if cropId then Inspection.Open(cropId) end
end

function Inspection.OnCropChanged(cropId)
    if active and active.cropId == cropId then forceSeries = true end
end

function Inspection.OnCropRemoved(cropId)
    if active and active.cropId == cropId then Inspection.Close('crop_removed') end
end

function Inspection.OnSyncReset()
    Inspection.Close('sync_reset')
end

function Inspection.IsActive()
    return active ~= nil
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Inspection.Close('resource_stop') end
end)
