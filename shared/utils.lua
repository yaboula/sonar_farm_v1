--[[
    sonar_farm - Shared pure utilities
    Small, side-effect-free helpers usable on both client and server.
    Namespaced under the global `Sonar` table.
]]

Sonar = Sonar or {}

local Utils = {}

--- Clamp a number to the [min, max] range.
---@param value number
---@param min number
---@param max number
---@return number
function Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Round a number to a given number of decimals (default 0).
---@param value number
---@param decimals? number
---@return number
function Utils.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

--- Squared distance between two vector3-like tables. Avoids sqrt when only
--- comparing distances (hot path for proximity checks).
---@param a vector3|table
---@param b vector3|table
---@return number
function Utils.DistanceSquared(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = (a.z or 0.0) - (b.z or 0.0)
    return dx * dx + dy * dy + dz * dz
end

--- Euclidean distance between two vector3-like tables.
---@param a vector3|table
---@param b vector3|table
---@return number
function Utils.Distance(a, b)
    return math.sqrt(Utils.DistanceSquared(a, b))
end

--- True when `a` is within `radius` meters of `b` (uses squared distance).
---@param a vector3|table
---@param b vector3|table
---@param radius number
---@return boolean
function Utils.IsWithin(a, b, radius)
    return Utils.DistanceSquared(a, b) <= (radius * radius)
end

--- Generate a short unique id. Good enough for in-memory keys and logs.
---@return string
function Utils.Uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx'
    return (template:gsub('[xy]', function(c)
        local r = math.random(0, 15)
        local v = (c == 'x') and r or ((r % 4) + 8)
        return string.format('%x', v)
    end))
end

--- Deep-merge `override` into a copy of `base`. Tables merge recursively;
--- scalar values from `override` win. Neither input is mutated.
---@param base table
---@param override table
---@return table
function Utils.DeepMerge(base, override)
    local result = {}
    for k, v in pairs(base or {}) do
        if type(v) == 'table' then
            result[k] = Utils.DeepMerge(v, {})
        else
            result[k] = v
        end
    end
    for k, v in pairs(override or {}) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = Utils.DeepMerge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

--- Number of key/value pairs in a table (works for non-array tables).
---@param t table
---@return number
function Utils.TableSize(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

--- Map a 0..100 quality score to a tier definition from Constants.QUALITY_TIERS.
---@param score number
---@return table tier
function Utils.QualityTier(score)
    local tiers = Sonar.Constants.QUALITY_TIERS
    local matched = tiers[1]
    for _, tier in ipairs(tiers) do
        if score >= tier.min then
            matched = tier
        end
    end
    return matched
end

Sonar.Utils = Utils
