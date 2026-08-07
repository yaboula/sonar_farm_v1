--[[
    sonar_farm - Zone and slot resolver (shared)
    Turns zone definitions into a flat, indexed list of planting slots.

    Slots replaced free-planting: a crop can only exist at a configured plot.
    That buys three things free-planting could never give us: no overlapping
    props, fields that look like actual crop rows, and a hard cap on how much can
    grow in a zone, which makes the economy a design decision instead of a
    consequence.

    Shared because both sides need the exact same slot list: the client to place
    interaction points and the server to validate where a crop may go. The server
    reads the position from here, never from the client, so planting position is
    not something a modified client can influence at all.

    Slot indices are 1-based. That is not only Lua convention: index 0 would break
    the NULLIF(?, '') trick used for nullable SQL columns, because '' casts to 0
    and a real slot 0 would be stored as NULL. See docs/RUNBOOK.md.
]]

Sonar = Sonar or {}

local Zones = {}

-- [zoneKey] = slot[]   (resolved lazily, then cached)
local resolved = {}

--- Rotate a local grid offset by `heading` degrees, so rows can be aligned with
--- the field instead of with the world axes.
---@param lx number
---@param ly number
---@param heading number degrees
---@return number dx
---@return number dy
local function rotate(lx, ly, heading)
    local rad = math.rad(heading or 0.0)
    local cos, sin = math.cos(rad), math.sin(rad)
    return (lx * cos) - (ly * sin), (lx * sin) + (ly * cos)
end

--- Expand a `grid` definition into slot positions. Generating them guarantees
--- the symmetry that hand-typed coordinates never quite achieve.
---@param grid table { origin, rows, cols, spacing = { x, y }, heading }
---@param out table slot array to append to
local function expandGrid(grid, out)
    local origin = grid.origin
    if not origin then return end

    local rows = math.max(1, math.floor(grid.rows or 1))
    local cols = math.max(1, math.floor(grid.cols or 1))
    local spacing = grid.spacing or {}
    local spacingX = spacing.x or 2.0
    local spacingY = spacing.y or 2.0
    local heading = grid.heading or 0.0

    -- Centre the block on the origin so moving `origin` moves the whole field
    -- rather than one of its corners.
    local offsetX = ((cols - 1) * spacingX) / 2
    local offsetY = ((rows - 1) * spacingY) / 2

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local dx, dy = rotate((col * spacingX) - offsetX, (row * spacingY) - offsetY, heading)
            out[#out + 1] = {
                x = origin.x + dx,
                y = origin.y + dy,
                z = origin.z,
                heading = heading,
            }
        end
    end
end

--- Resolve (and cache) the slot list for a zone.
---@param zoneKey string
---@return table[] slots
function Zones.Slots(zoneKey)
    if resolved[zoneKey] then
        return resolved[zoneKey]
    end

    local zone = Config.Zones and Config.Zones[zoneKey]
    if not zone then
        resolved[zoneKey] = {}
        return resolved[zoneKey]
    end

    local raw = {}

    -- Generated rows first, then any hand-placed extras.
    if zone.grid then
        expandGrid(zone.grid, raw)
    end

    for _, slot in ipairs(zone.slots or {}) do
        raw[#raw + 1] = {
            x = slot.x,
            y = slot.y,
            z = slot.z,
            heading = slot.heading or (zone.grid and zone.grid.heading) or 0.0,
        }
    end

    local slots = {}
    for index, slot in ipairs(raw) do
        slots[index] = {
            index = index,
            zone = zoneKey,
            key = ('%s:%d'):format(zoneKey, index),
            x = slot.x,
            y = slot.y,
            z = slot.z,
            heading = slot.heading or 0.0,
        }
    end

    resolved[zoneKey] = slots
    return slots
end

--- One slot by zone and index.
---@param zoneKey string
---@param index number
---@return table|nil slot
function Zones.Slot(zoneKey, index)
    index = tonumber(index)
    if not zoneKey or not index then return nil end
    return Zones.Slots(zoneKey)[index]
end

--- Number of slots configured in a zone. This is the zone's hard capacity.
---@param zoneKey string
---@return number
function Zones.Count(zoneKey)
    return #Zones.Slots(zoneKey)
end

--- Zone definition.
---@param zoneKey string
---@return table|nil
function Zones.Get(zoneKey)
    return Config.Zones and Config.Zones[zoneKey]
end

--- Whether a zone accepts a crop type. An empty or missing `allowedCrops`
--- means every crop is allowed.
---@param zoneKey string
---@param cropType string
---@return boolean
function Zones.AllowsCrop(zoneKey, cropType)
    local zone = Zones.Get(zoneKey)
    if not zone then return false end

    local allowed = zone.allowedCrops
    if not allowed or #allowed == 0 then return true end

    for _, key in ipairs(allowed) do
        if key == cropType then return true end
    end
    return false
end

--- Crop types plantable in a zone, sorted for stable menu ordering.
---@param zoneKey string
---@return string[]
function Zones.AllowedCrops(zoneKey)
    local zone = Zones.Get(zoneKey)
    local allowed = zone and zone.allowedCrops

    if allowed and #allowed > 0 then
        return allowed
    end

    local all = {}
    for cropType in pairs(Config.Crops or {}) do
        all[#all + 1] = cropType
    end
    table.sort(all)
    return all
end

--- Every slot across every zone.
---@return table[]
function Zones.AllSlots()
    local out = {}
    for zoneKey in pairs(Config.Zones or {}) do
        for _, slot in ipairs(Zones.Slots(zoneKey)) do
            out[#out + 1] = slot
        end
    end
    return out
end

--- Total configured capacity across all zones.
---@return number
function Zones.TotalSlots()
    return #Zones.AllSlots()
end

Sonar.Zones = Zones
