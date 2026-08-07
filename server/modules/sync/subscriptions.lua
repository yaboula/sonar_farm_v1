--[[
    sonar_farm - Cell subscriptions (server)
    Decides which players hear about which crops. A client subscribes to the cell
    it stands in plus the adjacent ones and gets a snapshot; from then on it only
    receives deltas for those cells. An idle field costs zero network traffic.

    Zero-Trust note: the subscribed cells are derived from the player's real
    server-side position, never from anything the client sends. Otherwise a
    modified client could subscribe to arbitrary cells and dump every crop on the
    map, including who owns what.

    The payload is deliberately minimal and carries timestamps rather than
    computed state: the client derives growth and condition locally with the same
    shared formula (see shared/growth.lua), so a growing crop never generates
    traffic while it grows.
]]

Sync = Sync or {}

local CALLBACKS = Sonar.Constants.CALLBACKS
local EVENTS = Sonar.Constants.EVENTS

-- [cellKey] = { [source] = true }
local subscribers = {}
-- [source] = { [cellKey] = true }
local playerCells = {}

-- ---------------------------------------------------------------------------
-- Subscription bookkeeping
-- ---------------------------------------------------------------------------

--- Cell keys in a square block around a world position.
---@param x number
---@param y number
---@param radius number cells in each direction (1 = 3x3 block)
---@return string[]
local function cellsAround(x, y, radius)
    local gx, gy = State.CellCoords(x, y)

    local keys = {}
    for dx = -radius, radius do
        for dy = -radius, radius do
            keys[#keys + 1] = State.CellKeyAt(gx + dx, gy + dy)
        end
    end
    return keys
end

--- Replace a player's subscribed cells with `cellKeys`.
---@param source number
---@param cellKeys string[]
local function resubscribe(source, cellKeys)
    local wanted = {}
    for _, key in ipairs(cellKeys) do
        wanted[key] = true
    end

    local current = playerCells[source]

    if current then
        for key in pairs(current) do
            if not wanted[key] then
                local bucket = subscribers[key]
                if bucket then
                    bucket[source] = nil
                    if next(bucket) == nil then
                        subscribers[key] = nil
                    end
                end
            end
        end
    end

    for key in pairs(wanted) do
        local bucket = subscribers[key]
        if not bucket then
            bucket = {}
            subscribers[key] = bucket
        end
        bucket[source] = true
    end

    playerCells[source] = wanted
end

-- ---------------------------------------------------------------------------
-- Payload
-- ---------------------------------------------------------------------------

--- Build the render payload for one crop, as seen by one recipient.
--- Ownership is reduced to a boolean: the raw identifier of another player never
--- reaches a client, so nobody can dump who owns which field.
---@param record table
---@param identifier string|nil recipient identifier
---@return table
local function renderPayload(record, identifier)
    local data = record.data or {}

    return {
        id = record.id,
        cropType = record.crop_type,
        zone = record.zone,
        slot = record.slot,
        cell = record.cell,
        x = record.pos_x,
        y = record.pos_y,
        z = record.pos_z,
        heading = record.heading or 0.0,
        plantedAt = record.planted_at,
        growthTime = record.growth_time,
        water = data.water,
        health = data.health,
        lastCare = data.lastCare,
        isMine = (record.owner == nil) or (record.owner == identifier),
    }
end

-- ---------------------------------------------------------------------------
-- Outbound deltas
-- ---------------------------------------------------------------------------

--- Notify subscribers that a crop was created or changed.
---@param record table
function Sync.OnCropChanged(record)
    if not record or not record.cell then return end

    local bucket = subscribers[record.cell]
    if not bucket then return end

    local now = Sonar.Time.Now()
    local invalid = {}
    for source in pairs(bucket) do
        local runtime = Runtime.GuardPlayer(source)
        if runtime.ok then
            TriggerClientEvent(EVENTS.CROP_SYNC, source, renderPayload(record, runtime.identifier), now)
        else
            invalid[#invalid + 1] = source
        end
    end
    for _, source in ipairs(invalid) do
        Sync.Release(source)
        TriggerClientEvent(EVENTS.SYNC_RESET, source)
    end
end

--- Notify subscribers that a crop no longer exists.
--- The cell must be passed explicitly: by the time this runs the record is
--- usually already gone from hot state.
---@param cropId string
---@param cellKey string
function Sync.OnCropRemoved(cropId, cellKey)
    if not cropId or not cellKey then return end

    local bucket = subscribers[cellKey]
    if not bucket then return end

    local invalid = {}
    for source in pairs(bucket) do
        if Runtime.GuardPlayer(source).ok then
            TriggerClientEvent(EVENTS.CROP_REMOVE, source, cropId)
        else
            invalid[#invalid + 1] = source
        end
    end
    for _, source in ipairs(invalid) do
        Sync.Release(source)
        TriggerClientEvent(EVENTS.SYNC_RESET, source)
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

--- Free a player's subscriptions. Called on disconnect.
---@param source number
function Sync.Release(source)
    local current = playerCells[source]
    if current then
        for key in pairs(current) do
            local bucket = subscribers[key]
            if bucket then
                bucket[source] = nil
                if next(bucket) == nil then
                    subscribers[key] = nil
                end
            end
        end
    end
    playerCells[source] = nil
end

AddEventHandler('playerDropped', function()
    Sync.Release(source)
end)

-- Routing bucket changes do not have a reliable client event. Check only
-- players with active subscriptions and clear their cache as soon as they leave
-- an allowed world instance.
CreateThread(function()
    while true do
        Wait(2000)
        local invalid = {}
        for source in pairs(playerCells) do
            if not Runtime.GuardPlayer(source).ok then
                invalid[#invalid + 1] = source
            end
        end
        for _, source in ipairs(invalid) do
            Sync.Release(source)
            TriggerClientEvent(EVENTS.SYNC_RESET, source)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Subscription callback
-- ---------------------------------------------------------------------------

-- Takes no arguments on purpose: the server decides which cells the player is
-- entitled to based on where the player actually is.
lib.callback.register(CALLBACKS.SUBSCRIBE, function(source)
    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then
        Sync.Release(source)
        return {
            ok = false,
            reason = runtime.reason,
            crops = {},
            serverTime = Sonar.Time.Now(),
        }
    end

    if not Security.Consume(source, 1, 'subscribe') then
        return {
            ok = false,
            reason = Sonar.Constants.REJECT.RATE_LIMITED,
            crops = {},
            serverTime = Sonar.Time.Now(),
        }
    end

    local coords = Validation.GetPlayerCoords(source)
    if not coords then
        -- Ped not streamed in yet. The client retries on its next tick.
        return {
            ok = false,
            reason = Sonar.Constants.REJECT.PLAYER_NOT_READY,
            crops = {},
            serverTime = Sonar.Time.Now(),
        }
    end

    local cellKeys = cellsAround(coords.x, coords.y, Config.Sync.CellRadius)
    resubscribe(source, cellKeys)

    local identifier = runtime.identifier
    local crops = {}
    for _, record in ipairs(State.GetByCells(cellKeys)) do
        crops[#crops + 1] = renderPayload(record, identifier)
    end

    -- serverTime lets the client align its clock, so a wrong local system clock
    -- cannot desync the growth it predicts.
    return {
        ok = true,
        cells = cellKeys,
        crops = crops,
        serverTime = Sonar.Time.Now(),
    }
end)
