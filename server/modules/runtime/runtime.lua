--[[
    sonar_farm - Runtime lifecycle gate (server)
    No gameplay callback may mutate or expose state before boot is complete.
]]

Runtime = Runtime or {}

Runtime.STATUS = {
    BOOTING = 'BOOTING',
    READY = 'READY',
    FAILED = 'FAILED',
    STOPPING = 'STOPPING',
}

Runtime.status = Runtime.status or Runtime.STATUS.BOOTING
Runtime.reason = Runtime.reason

function Runtime.SetStatus(status, reason)
    Runtime.status = status
    Runtime.reason = reason
end

function Runtime.IsReady()
    return Runtime.status == Runtime.STATUS.READY
end

local function bucketAllowed(bucket)
    for _, allowed in ipairs(Config.Security.AllowedRoutingBuckets or {}) do
        if bucket == allowed then return true end
    end
    return false
end

function Runtime.IsBucketAllowed(source)
    return bucketAllowed(GetPlayerRoutingBucket(source))
end

--- Guard a player-facing callback.
---@param source number
---@return table result
function Runtime.GuardPlayer(source)
    local reject = Sonar.Constants.REJECT

    if not Runtime.IsReady() then
        return { ok = false, reason = reject.SERVICE_UNAVAILABLE }
    end

    if not Runtime.IsBucketAllowed(source) then
        return { ok = false, reason = reject.WRONG_INSTANCE }
    end

    local identifier = Bridge.GetIdentifier(source)
    if type(identifier) ~= 'string' or identifier == '' then
        return { ok = false, reason = reject.PLAYER_NOT_READY }
    end

    return { ok = true, identifier = identifier }
end
