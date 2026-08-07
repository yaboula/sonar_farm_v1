--[[
    sonar_farm - Rate limiter (server)
    Token bucket per player against event flooding. Tickless: the bucket refills
    lazily from elapsed time on each consume, so idle players cost nothing.

    Owns its own state and cleans it up on playerDropped (no cross-module
    coupling: each security module frees what it allocates).
]]

Security = Security or {}

-- [source] = { tokens = number, last = ms }
local buckets = {}

local function bucketFor(source, now)
    local bucket = buckets[source]
    if not bucket then
        bucket = { tokens = Config.Security.TokenBucket.capacity, last = now }
        buckets[source] = bucket
    end
    return bucket
end

--- Try to spend `cost` tokens for a player. Returns false when the player is
--- flooding, in which case the caller must reject the action.
---@param source number
---@param cost? number defaults to 1
---@return boolean allowed
function Security.Consume(source, cost)
    cost = cost or 1

    local cfg = Config.Security.TokenBucket
    local now = GetGameTimer()
    local bucket = bucketFor(source, now)

    -- Lazy refill based on elapsed time since the last consume.
    local elapsed = (now - bucket.last) / 1000
    if elapsed > 0 then
        bucket.tokens = math.min(cfg.capacity, bucket.tokens + elapsed * cfg.refillPerSecond)
        bucket.last = now
    end

    if bucket.tokens < cost then
        Logger.Exploit(('Rate limit exceeded by %s.'):format(Bridge.GetPlayerName(source) or source), 'security', {
            source = source,
            identifier = Bridge.GetIdentifier(source),
            tokens = Sonar.Utils.Round(bucket.tokens, 2),
        })
        return false
    end

    bucket.tokens = bucket.tokens - cost
    return true
end

--- Current token count, for diagnostics.
---@param source number
---@return number
function Security.Tokens(source)
    local bucket = buckets[source]
    return bucket and bucket.tokens or Config.Security.TokenBucket.capacity
end

--- Release a player's bucket. Called on disconnect to avoid memory growth.
---@param source number
function Security.Release(source)
    buckets[source] = nil
end

AddEventHandler('playerDropped', function()
    Security.Release(source)
end)
