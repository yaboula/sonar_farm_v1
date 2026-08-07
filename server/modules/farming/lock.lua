--[[
    sonar_farm - In-flight action locks (server)
    Guards against the same crop being acted on twice concurrently. Without this
    two harvest callbacks arriving together could both pass validation and each
    deliver produce before either removed the crop from state (duplication).

    Locks are held only for the duration of a single handler, never persisted.
]]

Lock = Lock or {}

local held = {}

--- Try to take the lock for `key`. Returns false when already held.
---@param key string
---@return boolean acquired
function Lock.Acquire(key)
    if held[key] then return false end
    held[key] = true
    return true
end

--- Release the lock for `key`.
---@param key string
function Lock.Release(key)
    held[key] = nil
end

--- Run `fn` while holding the lock for `key`. Always releases, even on error.
---@param key string
---@param fn fun(): any
---@return boolean acquired
---@return any result value returned by `fn` (nil when not acquired)
function Lock.With(key, fn)
    if not Lock.Acquire(key) then
        return false, nil
    end

    local ok, result = pcall(fn)
    Lock.Release(key)

    if not ok then
        error(result, 0)
    end

    return true, result
end
