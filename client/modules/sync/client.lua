--[[
    sonar_farm - Sync client (client)
    The single thread that drives the whole visual engine. It watches which
    spatial cell the player is in, resubscribes when that changes, and reconciles
    the rendered props on each pass.

    One thread on purpose. Several threads with short waits are how a resource
    quietly climbs to 1 ms with nobody able to say which one is responsible; a
    single loop with an adaptive interval is measurable and easy to reason about.
]]

Sync = Sync or {}

local CALLBACKS = Sonar.Constants.CALLBACKS
local EVENTS = Sonar.Constants.EVENTS
local CELL_SIZE = Sonar.Constants.SPATIAL_CELL_SIZE

local currentCell = nil
local subscribing = false

-- Deltas that arrive while a subscription is in flight. The snapshot replaces the
-- whole cache, so without this buffer a crop planted during the round-trip would
-- be wiped from our cache and stay invisible until the next cell change.
local pendingDeltas = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Local cell key, matching the server's formula. Only used to decide *when* to
--- ask the server; the authoritative cell set is decided server-side.
---@param coords vector3
---@return string
local function localCellKey(coords)
    return ('%d:%d'):format(math.floor(coords.x / CELL_SIZE), math.floor(coords.y / CELL_SIZE))
end

--- Whether crops should be rendered at all right now.
---@param ped number
---@return boolean
local function renderAllowed(ped)
    if Config.Render.SkipInInteriors and GetInteriorFromEntity(ped) ~= 0 then
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Subscription
-- ---------------------------------------------------------------------------

--- Ask the server for the crops around us and replace the local cache.
--- Takes no arguments: the server derives the cells from our real position.
---@return boolean ok
local function requestSubscription()
    if subscribing then return false end

    subscribing = true
    pendingDeltas = {}

    local response = lib.callback.await(CALLBACKS.SUBSCRIBE, false)

    subscribing = false

    if not response then return false end

    -- Align our clock with the server before predicting anything from it.
    Sonar.Time.Sync(response.serverTime)

    if not response.ok then return false end

    Crops.ReplaceAll(response.crops)

    -- Re-apply anything that happened during the round-trip.
    for _, delta in ipairs(pendingDeltas) do
        if delta.removed then
            Crops.Remove(delta.id)
        else
            Crops.Upsert(delta.payload)
        end
    end
    pendingDeltas = {}

    return true
end

--- Resubscribe immediately, without waiting for the next tick.
function Sync.RefreshNow()
    currentCell = nil
    if requestSubscription() then
        currentCell = localCellKey(GetEntityCoords(PlayerPedId()))
        Crops.Refresh(GetEntityCoords(PlayerPedId()))
    end
end

-- ---------------------------------------------------------------------------
-- Inbound deltas
-- ---------------------------------------------------------------------------

RegisterNetEvent(EVENTS.CROP_SYNC, function(payload, serverTime)
    Sonar.Time.Sync(serverTime)

    if subscribing then
        pendingDeltas[#pendingDeltas + 1] = { payload = payload }
        return
    end

    Crops.Upsert(payload)
end)

RegisterNetEvent(EVENTS.CROP_REMOVE, function(cropId)
    if subscribing then
        pendingDeltas[#pendingDeltas + 1] = { id = cropId, removed = true }
        return
    end

    Crops.Remove(cropId)
end)

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

CreateThread(function()
    Target.RegisterZones()

    while true do
        local interval = Config.Sync.TickFar
        local ped = PlayerPedId()

        if ped and ped ~= 0 and renderAllowed(ped) then
            local coords = GetEntityCoords(ped)

            -- Ped not spawned yet: coords are the world origin. Retry later.
            if math.abs(coords.x) > 1.0 or math.abs(coords.y) > 1.0 then
                local cell = localCellKey(coords)

                if cell ~= currentCell then
                    if requestSubscription() then
                        currentCell = cell
                    end
                end

                Crops.Refresh(coords)

                -- Only tighten the loop when there is actually something around.
                interval = (Crops.Count() > 0) and Config.Sync.TickNear or Config.Sync.TickFar
            end
        elseif Pool.Count() > 0 then
            -- Entered an interior with props still up: drop them, keep the cache.
            Crops.DespawnAll()
        end

        Wait(interval)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Crops.Reset()
end)
