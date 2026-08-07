--[[
    sonar_farm - Quality (server)
    The contract between farming actions and whatever decides "how well did the
    player perform". Today a stub returns a flat score; in Stage 5 the minigame
    module registers a real provider and NOTHING in plant/care/harvest changes.

    The score is always produced server-side (or validated server-side by the
    provider). A client can never report its own 100%.
]]

Quality = Quality or {}

local Utils = Sonar.Utils

-- [name] = fn(source, action, record) -> number 0..100
local providers = {}
local activeProvider = 'default'

-- ---------------------------------------------------------------------------
-- Providers
-- ---------------------------------------------------------------------------

--- Register a score provider.
---@param name string
---@param fn fun(source: number, action: string, record: table): number
function Quality.RegisterProvider(name, fn)
    if type(fn) ~= 'function' then
        Logger.Warn(('Quality provider "%s" is not a function; ignored.'):format(tostring(name)), 'quality')
        return
    end
    providers[name] = fn
    Logger.Info(('Quality provider registered: %s'):format(name), 'quality')
end

--- Select the active provider.
---@param name string
---@return boolean ok
function Quality.SetProvider(name)
    if not providers[name] then
        Logger.Warn(('Unknown quality provider "%s"; keeping "%s".'):format(tostring(name), activeProvider), 'quality')
        return false
    end
    activeProvider = name
    return true
end

--- Ask the active provider for a performance score.
---@param source number
---@param action string one of Sonar.Constants.ACTIONS
---@param record table
---@return number score 0..100
function Quality.Request(source, action, record)
    local provider = providers[activeProvider] or providers.default
    local ok, score = pcall(provider, source, action, record)

    if not ok or type(score) ~= 'number' then
        Logger.Warn(('Quality provider "%s" failed; falling back to default score.'):format(activeProvider), 'quality')
        score = Config.Quality.DefaultScore
    end

    return Utils.Clamp(score, 0, 100)
end

-- Stub provider used until the minigame module (Stage 5) registers its own.
Quality.RegisterProvider('default', function()
    return Config.Quality.DefaultScore
end)

-- ---------------------------------------------------------------------------
-- Final quality and yield
-- ---------------------------------------------------------------------------

--- Combine the action score with how well the crop was cared for.
--- Care state (health) and spoilage are what make attentive farming pay off.
---@param score number 0..100 from the provider
---@param condition table from Physiology.Evaluate
---@param opts? table { theft = boolean, mechanized = boolean }
---@return number quality 0..100
function Quality.Resolve(score, condition, opts)
    opts = opts or {}

    local cfg = Config.Quality
    local careScore = condition.health or 100

    local quality = (score * cfg.ScoreWeight) + (careScore * cfg.CareWeight)

    -- Spoilage is a direct multiplier: produce left rotting loses value.
    quality = quality * (1 - Utils.Clamp((condition.spoilage or 0) / 100, 0, 1))

    -- Mechanized work trades quality for scale (Stage 9+).
    if opts.mechanized then
        quality = math.min(quality, cfg.MechanizedCap)
    end

    -- Stolen produce is worth less: it is handled hastily and sold discreetly.
    if opts.theft then
        quality = quality * (1 - Utils.Clamp(Config.Farming.TheftQualityPenalty, 0, 1))
    end

    return Utils.Round(Utils.Clamp(quality, 0, 100), 1)
end

--- Yield units for a harvest, scaled by final quality.
---@param record table
---@param quality number 0..100
---@return number units at least 1 unless the crop is dead
function Quality.Yield(record, quality)
    local def = Config.Crops and Config.Crops[record.crop_type]
    local range = (def and def.yield) or { min = 1, max = 3 }

    local min = range.min or 1
    local max = range.max or min

    -- Quality interpolates between the minimum and maximum yield.
    local units = min + (max - min) * (Utils.Clamp(quality, 0, 100) / 100)

    return math.max(1, math.floor(units + 0.5))
end

--- Build the ox_inventory metadata attached to harvested produce.
---@param record table
---@param quality number
---@return table metadata
function Quality.Metadata(record, quality)
    local tier = Utils.QualityTier(quality)
    return {
        quality = quality,
        tier = tier.key,
        label = tier.label,
        crop = record.crop_type,
        harvestedAt = os.time(),
    }
end
