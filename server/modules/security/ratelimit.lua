--[[
    sonar_farm - Rate limiter (server)
    Token bucket per player against event flooding. Tickless: the bucket refills
    lazily from elapsed time on each consume, so idle players cost nothing.

    Owns its own state and cleans it up on playerDropped (no cross-module
    coupling: each security module frees what it allocates).
]]

Security = Security or {}

-- [source] = { [scope] = { tokens = number, last = ms } }
local buckets = {}
-- [source] = { [scope] = lastLogMs }
local violationLogs = {}

local function configFor(scope)
    if scope == 'subscribe' then
        return Config.Security.SubscriptionBucket
    end
    return Config.Security.TokenBucket
end

local function bucketFor(source, scope, now, cfg)
    local playerBuckets = buckets[source]
    if not playerBuckets then
        playerBuckets = {}
        buckets[source] = playerBuckets
    end

    local bucket = playerBuckets[scope]
    if not bucket then
        bucket = { tokens = cfg.capacity, last = now }
        playerBuckets[scope] = bucket
    end
    return bucket
end

--- Try to spend `cost` tokens for a player. Returns false when the player is
--- flooding, in which case the caller must reject the action.
---@param source number
---@param cost? number defaults to 1
---@param scope? string defaults to action
---@return boolean allowed
function Security.Consume(source, cost, scope)
    cost = cost or 1
    scope = scope or 'action'

    local cfg = configFor(scope)
    local now = GetGameTimer()
    local bucket = bucketFor(source, scope, now, cfg)

    -- Lazy refill based on elapsed time since the last consume.
    local elapsed = (now - bucket.last) / 1000
    if elapsed > 0 then
        bucket.tokens = math.min(cfg.capacity, bucket.tokens + elapsed * cfg.refillPerSecond)
        bucket.last = now
    end

    if bucket.tokens < cost then
        local playerLogs = violationLogs[source] or {}
        violationLogs[source] = playerLogs
        local interval = Config.Security.RateLimitLogInterval or 5000
        if not playerLogs[scope] or (now - playerLogs[scope]) >= interval then
            playerLogs[scope] = now
            Logger.Exploit(('Rate limit exceeded by %s.'):format(Bridge.GetPlayerName(source) or source), 'security', {
                source = source,
                identifier = Bridge.GetIdentifier(source),
                scope = scope,
                tokens = Sonar.Utils.Round(bucket.tokens, 2),
            })
        end
        return false
    end

    bucket.tokens = bucket.tokens - cost
    return true
end

--- Current token count, for diagnostics.
---@param source number
---@return number
function Security.Tokens(source, scope)
    scope = scope or 'action'
    local playerBuckets = buckets[source]
    local bucket = playerBuckets and playerBuckets[scope]
    return bucket and bucket.tokens or configFor(scope).capacity
end

--- Release a player's bucket. Called on disconnect to avoid memory growth.
---@param source number
function Security.Release(source)
    buckets[source] = nil
    violationLogs[source] = nil
end

AddEventHandler('playerDropped', function()
    Security.Release(source)
end)
