--[[
    sonar_farm - State manager (server)
    Authoritative in-memory hot state for crops. RAM is the source of truth
    during gameplay; the DB is an async backup. Writes are tracked with dirty /
    deleted sets and flushed in batches (snapshot swap, see State.Flush).

    Record shape (mirrors farming_crops columns; data is a Lua table):
      id, crop_type, owner, zone, cell,
      pos_x, pos_y, pos_z, heading,
      planted_at, growth_time, state, data
]]

State = State or {}

State.crops = State.crops or {}     -- [id] = record
State.cells = State.cells or {}     -- [cellKey] = { [id] = true }  (spatial index)
State.dirty = State.dirty or {}     -- [id] = true  (pending upsert)
State.deleted = State.deleted or {} -- [id] = true  (pending delete)
State.loaded = false

local CELL_SIZE = Sonar.Constants.SPATIAL_CELL_SIZE
local Uuid = Sonar.Utils.Uuid
local DeepMerge = Sonar.Utils.DeepMerge

-- ---------------------------------------------------------------------------
-- Spatial index helpers
-- ---------------------------------------------------------------------------

--- Compute the spatial-hash cell key for a world position.
---@param x number
---@param y number
---@return string cellKey "gx:gy"
function State.CellKey(x, y)
    return ('%d:%d'):format(math.floor(x / CELL_SIZE), math.floor(y / CELL_SIZE))
end

local function indexAdd(record)
    local bucket = State.cells[record.cell]
    if not bucket then
        bucket = {}
        State.cells[record.cell] = bucket
    end
    bucket[record.id] = true
end

local function indexRemove(record)
    local bucket = State.cells[record.cell]
    if bucket then
        bucket[record.id] = nil
        if next(bucket) == nil then
            State.cells[record.cell] = nil
        end
    end
end

local function markDirty(id)
    State.dirty[id] = true
    State.deleted[id] = nil
end

-- ---------------------------------------------------------------------------
-- CRUD (in-memory; persistence is deferred to Flush)
-- ---------------------------------------------------------------------------

--- Add a crop to hot state. Generates id/cell/timestamps when missing.
---@param partial table
---@return string id
---@return table record
function State.Add(partial)
    local id = partial.id or Uuid()
    local def = Config.Crops[partial.crop_type]

    local record = {
        id = id,
        crop_type = partial.crop_type,
        owner = partial.owner,
        zone = partial.zone,
        pos_x = partial.pos_x,
        pos_y = partial.pos_y,
        pos_z = partial.pos_z,
        heading = partial.heading or 0.0,
        planted_at = partial.planted_at or os.time(),
        growth_time = partial.growth_time or (def and def.growthTime) or 0,
        state = partial.state or Sonar.Constants.CROP_STATE.PLANTED,
        data = partial.data or {},
    }
    record.cell = partial.cell or State.CellKey(record.pos_x, record.pos_y)

    State.crops[id] = record
    indexAdd(record)
    markDirty(id)

    return id, record
end

--- Get a crop record by id.
---@param id string
---@return table|nil
function State.Get(id)
    return State.crops[id]
end

--- Patch a crop record. `data` merges deeply; position changes reindex the cell.
---@param id string
---@param patch table
---@return boolean ok
function State.Update(id, patch)
    local record = State.crops[id]
    if not record then return false end

    local posChanged = false
    for k, v in pairs(patch) do
        if k == 'data' and type(v) == 'table' then
            record.data = DeepMerge(record.data or {}, v)
        else
            if k == 'pos_x' or k == 'pos_y' then posChanged = true end
            record[k] = v
        end
    end

    if posChanged then
        indexRemove(record)
        record.cell = State.CellKey(record.pos_x, record.pos_y)
        indexAdd(record)
    end

    markDirty(id)
    return true
end

--- Remove a crop from hot state and queue it for deletion.
---@param id string
---@return boolean ok
function State.Remove(id)
    local record = State.crops[id]
    if not record then return false end

    indexRemove(record)
    State.crops[id] = nil
    State.dirty[id] = nil
    State.deleted[id] = true
    return true
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

--- All crop records in a spatial cell.
---@param cellKey string
---@return table[]
function State.GetByCell(cellKey)
    local out = {}
    local bucket = State.cells[cellKey]
    if bucket then
        for id in pairs(bucket) do
            out[#out + 1] = State.crops[id]
        end
    end
    return out
end

--- All crop records in a named zone.
---@param zone string
---@return table[]
function State.GetByZone(zone)
    local out = {}
    for _, record in pairs(State.crops) do
        if record.zone == zone then
            out[#out + 1] = record
        end
    end
    return out
end

--- The full hot-state table (do not mutate directly).
---@return table<string, table>
function State.All()
    return State.crops
end

--- Number of crops in hot state.
---@return number
function State.Count()
    local n = 0
    for _ in pairs(State.crops) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------
-- Load
-- ---------------------------------------------------------------------------

--- Load all crops from the DB into hot state. Safe JSON decode: a corrupt
--- `data` blob falls back to {} and is logged, without aborting the load.
---@return number loaded
function State.LoadAll()
    local rows = Database.LoadAllCrops()

    State.crops = {}
    State.cells = {}
    State.dirty = {}
    State.deleted = {}

    local corrupt = 0
    for _, row in ipairs(rows) do
        local data = {}
        if row.data and row.data ~= '' then
            local ok, decoded = pcall(json.decode, row.data)
            if ok and type(decoded) == 'table' then
                data = decoded
            else
                corrupt = corrupt + 1
                Logger.Warn(('Corrupt data JSON for crop %s, using empty table.'):format(tostring(row.id)), 'state')
            end
        end

        local record = {
            id = row.id,
            crop_type = row.crop_type,
            owner = row.owner,
            zone = row.zone,
            cell = row.cell,
            pos_x = row.pos_x,
            pos_y = row.pos_y,
            pos_z = row.pos_z,
            heading = row.heading or 0.0,
            planted_at = row.planted_at,
            growth_time = row.growth_time or 0,
            state = row.state or Sonar.Constants.CROP_STATE.PLANTED,
            data = data,
        }

        State.crops[record.id] = record
        indexAdd(record)
    end

    State.loaded = true
    if corrupt > 0 then
        Logger.Warn(('Loaded with %d corrupt data blob(s).'):format(corrupt), 'state')
    end
    return State.Count()
end

-- ---------------------------------------------------------------------------
-- Flush (persistence). Must run within a thread (uses oxmysql .await).
-- ---------------------------------------------------------------------------

--- Snapshot-swap flush. Detaches the dirty/deleted sets before awaiting the DB
--- so writes during the transaction are not lost; on failure the affected ids
--- are re-queued (merge) instead of dropped.
---@return boolean ok
local function doFlush()
    if next(State.dirty) == nil and next(State.deleted) == nil then
        return true
    end

    -- Snapshot swap: new sets capture any writes that happen during the await.
    local dirtySnapshot = State.dirty
    local deletedSnapshot = State.deleted
    State.dirty = {}
    State.deleted = {}

    -- Build upsert rows from live records only (skip ids removed meanwhile).
    local rows = {}
    for id in pairs(dirtySnapshot) do
        local record = State.crops[id]
        if record then
            rows[#rows + 1] = record
        end
    end

    local deleteIds = {}
    for id in pairs(deletedSnapshot) do
        deleteIds[#deleteIds + 1] = id
    end

    local okUpsert = Database.UpsertCrops(rows)
    local okDelete = Database.DeleteCrops(deleteIds)

    -- Re-queue whatever failed to persist, without clobbering fresher marks.
    if not okUpsert then
        for id in pairs(dirtySnapshot) do
            if State.crops[id] and not State.deleted[id] then
                State.dirty[id] = true
            end
        end
    end
    if not okDelete then
        for id in pairs(deletedSnapshot) do
            if not State.crops[id] then
                State.deleted[id] = true
            end
        end
    end

    return okUpsert and okDelete
end

--- Async batch flush of pending changes.
---@return boolean ok
function State.Flush()
    return doFlush()
end

--- Emergency flush for onResourceStop / shutdown. Same logic as Flush; relies
--- on oxmysql's awaitable API completing during graceful stops. The periodic
--- save is the primary safety net (see docs/RUNBOOK.md).
---@return boolean ok
function State.FlushSync()
    return doFlush()
end
