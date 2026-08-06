--[[
    sonar_farm - Main configuration
    All values here are safe to edit by server owners.
    Code, comments and config are English-only by project convention.
]]

Config = {}

-- ---------------------------------------------------------------------------
-- Framework
-- ---------------------------------------------------------------------------
-- 'auto'    -> the Bridge auto-detects the running framework via GetResourceState.
-- 'qb-core' -> force QB-Core.
-- 'esx'     -> force ESX (adapter is a stub for now).
-- 'qbox'    -> force Qbox (adapter is a stub for now).
Config.Framework = 'auto'

-- Resource names per framework, used for detection and core access.
-- Change these only if your server renames the core resources.
Config.FrameworkResources = {
    ['qb-core'] = 'qb-core',
    ['esx'] = 'es_extended',
    ['qbox'] = 'qbx_core',
}

-- ---------------------------------------------------------------------------
-- Debug & diagnostics
-- ---------------------------------------------------------------------------
-- When true, prints verbose logs and enables developer helpers.
Config.Debug = true

-- ---------------------------------------------------------------------------
-- Persistence (used from Stage 2 onwards)
-- ---------------------------------------------------------------------------
-- Interval, in seconds, for the async batch save of dirty state to the DB.
Config.SaveInterval = 60

Config.Database = {
    -- When true, the resource runs database/install.sql at boot (idempotent,
    -- CREATE TABLE IF NOT EXISTS). Set false if you import the SQL manually.
    AutoCreateSchema = true,
    -- Max rows per upsert/delete transaction chunk. Keeps transactions small
    -- and well under max_allowed_packet under heavy load.
    BatchChunkSize = 100,
}

-- ---------------------------------------------------------------------------
-- Locale
-- ---------------------------------------------------------------------------
-- UI strings are English-only by design. Kept here for future-proofing.
Config.Locale = 'en'

-- ---------------------------------------------------------------------------
-- Feature flags
-- Toggle whole subsystems without touching code. Useful for staged rollout.
-- ---------------------------------------------------------------------------
Config.Features = {
    Minigames = true,      -- Stage 5: active skill-based minigames
    Machinery = true,      -- Stage 9+: mechanized farming (quality cap + risk)
    Progression = true,    -- Stage 7: XP + tech-tree
    Economy = true,        -- Stage 8: sell to NPC, quality-based pricing
    Discord = false,       -- Stage 3: Discord webhook logging connector
    DatabaseLogs = false,  -- Stage 3: database logging connector
}

-- ---------------------------------------------------------------------------
-- Logging
-- ---------------------------------------------------------------------------
Config.Logging = {
    -- Minimum level printed to the server console: 'INFO' | 'WARN' | 'EXPLOIT'.
    ConsoleLevel = 'INFO',
    -- Discord webhook URL (only used when Config.Features.Discord is true).
    DiscordWebhook = '',
}
