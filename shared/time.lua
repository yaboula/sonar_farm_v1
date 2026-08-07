--[[
    sonar_farm - Shared clock
    Growth and physiology are pure functions of elapsed time, and from Stage 4 the
    client derives them locally to avoid streaming state over the network. That
    only works if both sides agree on "now".

    A player whose system clock is wrong (or in a different timezone offset) would
    otherwise see plants at the wrong stage. The server sends its own timestamp
    with every sync payload and the client stores the difference, so all time math
    runs on server time regardless of the local clock.

    On the server the offset is always zero: Now() is plain os.time().
]]

Sonar = Sonar or {}

local Time = {}

local offset = 0

--- Returns current unix seconds. Uses os.time() on the server and
--- GetNetworkTimeAccurate() on the client (FiveM client Lua has no os library).
local function unixNow()
    if type(os) == 'table' then
        -- Server-side: os library is available
        return os.time()
    else
        -- Client-side: GetNetworkTimeAccurate returns milliseconds since epoch
        return math.floor(GetNetworkTimeAccurate() / 1000)
    end
end

--- Current time in server-aligned unix seconds.
---@return number
function Time.Now()
    return unixNow() + offset
end

--- Align the local clock with the server. Called by the client sync layer on
--- every snapshot; no-op on the server.
---@param serverNow number unix seconds as reported by the server
function Time.Sync(serverNow)
    if type(serverNow) ~= 'number' then return end
    offset = serverNow - unixNow()
end

--- Current drift between the local clock and the server, in seconds.
---@return number
function Time.Offset()
    return offset
end

Sonar.Time = Time
