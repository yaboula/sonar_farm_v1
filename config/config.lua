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
-- Sync (Stage 4): what each client is told about, and how often
-- ---------------------------------------------------------------------------
Config.Sync = {
    -- Spatial cells around the player that get subscribed. 1 = the player's cell
    -- plus the 8 adjacent ones (300x300m with 100m cells), so data is always
    -- available ahead of the player in every direction.
    CellRadius = 1,
    -- Cell-check interval (ms) when there is at least one crop nearby.
    TickNear = 500,
    -- Cell-check interval (ms) when the player is nowhere near a crop. Keeps the
    -- idle cost effectively zero.
    TickFar = 2000,
}

-- ---------------------------------------------------------------------------
-- Render (Stage 4): client-side props, culling and interaction
-- ---------------------------------------------------------------------------
Config.Render = {
    -- Props are created only within this distance (meters) of the player.
    Radius = 30.0,
    -- Hard ceiling on simultaneous crop props. Closest crops win. Protects the
    -- pathological case of many players planting in one small area.
    MaxProps = 50,
    -- Snap props to the ground with a raycast instead of trusting the stored
    -- pos_z (which is the planter's foot position and may be on a slope).
    GroundSnap = true,
    -- Deterministic per-crop rotation/scale variation so fields do not look
    -- like a cloned grid. Derived from the crop id, so every client agrees.
    Variation = true,
    -- ox_target interaction distance. Deliberately below
    -- Security.MaxInteractDistance so a legitimate player can never get a
    -- `too_far` rejection from something ox_target let them click.
    TargetDistance = 2.2,
    -- Skip rendering while the player is inside an interior. Routing buckets are
    -- not readable client-side, so the interior check is the practical proxy for
    -- "the player is not out in the field".
    SkipInInteriors = true,
    -- Fallback model used when a configured crop model is missing (bad name, or
    -- the prop pack resource is not running). Keeps the crop interactable.
    FallbackModel = 'prop_plant_01a',
    -- Optional prop marking an empty planting slot (tilled soil, a stake...).
    -- Set to a model name from your prop pack to make free plots visible, or
    -- false to leave them clean. Interaction works either way: every slot has
    -- its own ox_target point regardless of whether a prop is drawn.
    SlotProp = false,
    -- Interaction radius (meters) of an empty slot's target point. Slightly
    -- larger than a crop's, since there may be nothing visible to aim at.
    SlotTargetRadius = 1.2,
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
