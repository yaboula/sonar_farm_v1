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
-- Security (Stage 3): server-authoritative validation and anti-exploit
-- ---------------------------------------------------------------------------
Config.Security = {
    -- Token bucket per player against event flooding. `capacity` is the burst
    -- allowance; `refillPerSecond` how fast it recovers.
    TokenBucket = {
        capacity = 8,
        refillPerSecond = 2,
    },
    -- Max distance (meters) between the player and the crop for any action.
    MaxInteractDistance = 3.0,
    -- Implied speed (m/s) above which movement is considered suspicious.
    -- ~60 m/s tolerates fast vehicles and planes without flagging them.
    MaxSpeedMps = 60.0,
    -- If the cached position sample is older than this (seconds), skip the
    -- speed check: the player may have changed routing bucket or interior.
    PositionSampleTtl = 30,
    -- Grace period (seconds) after connecting during which the speed check is
    -- skipped, since coords are unreliable while the ped streams in.
    ConnectGracePeriod = 15,
}

-- Per-action cooldowns in milliseconds.
Config.Cooldowns = {
    plant = 1000,
    water = 500,
    harvest = 1000,
}

-- ---------------------------------------------------------------------------
-- Farming rules (Stage 3)
-- ---------------------------------------------------------------------------
Config.Farming = {
    -- Only the player who planted a crop may harvest it. When false, anyone
    -- can harvest but stolen produce loses quality (TheftQualityPenalty).
    OwnerOnlyHarvest = true,
    -- Anyone may water/care for someone else's crop in public zones. Enables
    -- cooperative play (saving a neighbour's withering crop) without allowing
    -- theft of the produce.
    AllowPublicCare = true,
    -- Quality lost (0..1) when harvesting a crop you do not own.
    TheftQualityPenalty = 0.3,
    -- Max simultaneous active crops per player in public zones. Prevents a
    -- single player from monopolizing a zone before private plots exist.
    MaxCropsPerPlayer = 25,
    -- Minimum water level (0..100) below which watering is allowed again.
    -- Prevents spam-watering an already saturated crop.
    WaterRefillThreshold = 95,
    -- Tools required per action (ox_inventory item names).
    Tools = {
        water = 'watering_can',
    },
}

-- ---------------------------------------------------------------------------
-- Quality (Stage 3 contract, Stage 5 minigames)
-- ---------------------------------------------------------------------------
Config.Quality = {
    -- Score returned by the default (stub) provider until minigames land.
    DefaultScore = 75,
    -- Quality ceiling for mechanized/automated work (Stage 9+). Manual work
    -- with minigames can reach 100.
    MechanizedCap = 80,
    -- Weight of the action score vs. the crop's care state in final quality.
    ScoreWeight = 0.6,
    CareWeight = 0.4,
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
