--[[
    sonar_farm - Database layer (server)
    Thin, parameterized access over oxmysql (MySQL global from
    @oxmysql/lib/MySQL.lua). No business logic here: schema bootstrap plus
    load/upsert/delete for farming_crops. Batched and chunked for safety.
]]

Database = Database or {}

local CROPS_TABLE = 'farming_crops'

-- Column order shared by the upsert builder and the row serializer.
local UPSERT_COLUMNS = {
    'id', 'crop_type', 'owner', 'zone', 'cell',
    'pos_x', 'pos_y', 'pos_z', 'heading',
    'planted_at', 'growth_time', 'state', 'data',
}

-- ---------------------------------------------------------------------------
-- Init & schema
-- ---------------------------------------------------------------------------

--- Wait for oxmysql, then optionally create the schema. Must run in a thread.
---@return boolean ok
function Database.Init()
    local attempts = 0
    while GetResourceState('oxmysql') ~= 'started' and attempts < 100 do
        attempts = attempts + 1
        Wait(100)
    end

    if GetResourceState('oxmysql') ~= 'started' then
        Logger.Warn('oxmysql is not started. Persistence is unavailable.', 'db')
        return false
    end

    if Config.Database.AutoCreateSchema then
        if not Database.EnsureSchema() then
            return false
        end
    end

    return true
end

--- Create tables from database/install.sql (idempotent). Falls back to an
--- inline DDL if the file cannot be read.
---@return boolean ok
function Database.EnsureSchema()
    local sql = LoadResourceFile(Sonar.Constants.RESOURCE, 'database/install.sql')

    if not sql or sql == '' then
        Logger.Warn('Could not read database/install.sql, using inline DDL fallback.', 'db')
        sql = ([[CREATE TABLE IF NOT EXISTS `%s` (
            `id` VARCHAR(36) NOT NULL,
            `crop_type` VARCHAR(64) NOT NULL,
            `owner` VARCHAR(64) DEFAULT NULL,
            `zone` VARCHAR(64) DEFAULT NULL,
            `cell` VARCHAR(32) NOT NULL,
            `pos_x` DOUBLE NOT NULL,
            `pos_y` DOUBLE NOT NULL,
            `pos_z` DOUBLE NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `planted_at` BIGINT NOT NULL,
            `growth_time` INT NOT NULL DEFAULT 0,
            `state` VARCHAR(16) NOT NULL DEFAULT 'planted',
            `data` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_cell` (`cell`),
            KEY `idx_zone` (`zone`),
            KEY `idx_owner` (`owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]]):format(CROPS_TABLE)
    end

    local ok, err = pcall(function()
        MySQL.query.await(sql)
    end)

    if not ok then
        Logger.Warn(('Schema creation failed: %s'):format(tostring(err)), 'db')
        return false
    end

    Logger.Info('Schema ensured.', 'db')
    return true
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Split an array into chunks of `size`.
---@generic T
---@param arr T[]
---@param size number
---@return T[][]
local function chunk(arr, size)
    local chunks = {}
    for i = 1, #arr, size do
        local piece = {}
        for j = i, math.min(i + size - 1, #arr) do
            piece[#piece + 1] = arr[j]
        end
        chunks[#chunks + 1] = piece
    end
    return chunks
end

-- Nullable columns. Sent as '' and converted to SQL NULL via NULLIF so the
-- parameter array never contains nil (a nil hole breaks array binding).
local NULLABLE_COLUMNS = { owner = true, zone = true, data = true }

-- Prebuilt upsert statement (placeholders only, never string concatenation).
local UPSERT_SQL do
    local cols, placeholders, updates = {}, {}, {}
    for _, col in ipairs(UPSERT_COLUMNS) do
        cols[#cols + 1] = ('`%s`'):format(col)
        placeholders[#placeholders + 1] = NULLABLE_COLUMNS[col] and "NULLIF(?, '')" or '?'
        if col ~= 'id' then
            updates[#updates + 1] = ('`%s`=VALUES(`%s`)'):format(col, col)
        end
    end
    UPSERT_SQL = ('INSERT INTO `%s` (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s'):format(
        CROPS_TABLE,
        table.concat(cols, ', '),
        table.concat(placeholders, ', '),
        table.concat(updates, ', ')
    )
end

--- Serialize a state record into an ordered parameter array for UPSERT_SQL.
--- `data` is JSON-encoded here so callers pass a plain Lua table. Nullable
--- values become '' (see NULLABLE_COLUMNS) to keep the array dense.
---@param row table
---@return any[]
local function serializeRow(row)
    return {
        row.id,
        row.crop_type,
        row.owner or '',
        row.zone or '',
        row.cell,
        row.pos_x,
        row.pos_y,
        row.pos_z,
        row.heading or 0,
        row.planted_at,
        row.growth_time or 0,
        row.state or 'planted',
        row.data and json.encode(row.data) or '',
    }
end

-- ---------------------------------------------------------------------------
-- CRUD
-- ---------------------------------------------------------------------------

--- Load every crop row. `data` is returned raw (string); the caller decodes it
--- safely (see State.LoadAll).
---@return table[] rows
function Database.LoadAllCrops()
    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT * FROM `%s`'):format(CROPS_TABLE))
    end)
    if not ok then
        Logger.Warn(('LoadAllCrops failed: %s'):format(tostring(rows)), 'db')
        return {}
    end
    return rows or {}
end

--- Upsert a batch of crop records. Chunked transactions with parameters.
---@param rows table[] state records (data as a Lua table)
---@return boolean ok
function Database.UpsertCrops(rows)
    if not rows or #rows == 0 then return true end

    for _, piece in ipairs(chunk(rows, Config.Database.BatchChunkSize)) do
        local queries = {}
        for _, row in ipairs(piece) do
            queries[#queries + 1] = { query = UPSERT_SQL, values = serializeRow(row) }
        end

        local ok, err = pcall(function()
            MySQL.transaction.await(queries)
        end)

        if not ok then
            Logger.Warn(('UpsertCrops chunk failed (%d rows): %s'):format(#piece, tostring(err)), 'db')
            return false
        end
    end

    return true
end

--- Delete a batch of crops by id. Chunked, parameterized IN clauses.
---@param ids string[]
---@return boolean ok
function Database.DeleteCrops(ids)
    if not ids or #ids == 0 then return true end

    for _, piece in ipairs(chunk(ids, Config.Database.BatchChunkSize)) do
        local placeholders = {}
        for i = 1, #piece do placeholders[i] = '?' end
        local sql = ('DELETE FROM `%s` WHERE `id` IN (%s)'):format(CROPS_TABLE, table.concat(placeholders, ', '))

        local ok, err = pcall(function()
            MySQL.query.await(sql, piece)
        end)

        if not ok then
            Logger.Warn(('DeleteCrops chunk failed (%d ids): %s'):format(#piece, tostring(err)), 'db')
            return false
        end
    end

    return true
end
