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

-- Deterministic auto-detection order. Only QB-Core is implemented in the MVP;
-- the remaining entries exist so forced/accidental selection fails clearly.
Config.FrameworkPriority = { 'qb-core', 'qbox', 'esx' }

-- ---------------------------------------------------------------------------
-- Debug & diagnostics
-- ---------------------------------------------------------------------------
-- When true, prints verbose logs and exposes developer helpers to authorized
-- administrators. It never grants permission on its own.
Config.Debug = false

Config.Admin = {
    Ace = 'sonar_farm.admin',
}

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
    Minigames = false,      -- Stage 5: authoritative tomato planting enabled
    AdvancedCare = true,  -- Causal nutrients/weeds/pests model; opt-in rollout
    InspectionHud = true,  -- Focus-free authoritative crop inspection rail
    Supplies = true,      -- Authoritative Company procurement and Warehouse
    Fields = true,         -- Authoritative Field catalogue, ownership and Hub maps
    CompanyFieldAuthority = false, -- Atomic cutover to Company-only farming
    Work = false,          -- Assignments and structured Crop Plan execution
    PublicContracts = false,
    CompanyCargo = false,
    BuyerOrders = false,
    Machinery = false,     -- Stage 9+: not implemented
    Progression = false,   -- Stage 7: not implemented
    Economy = false,       -- Stage 8: not implemented
    Discord = false,       -- Stage 3: Discord webhook logging connector
    DatabaseLogs = false,  -- Stage 3: database logging connector
}

Config.Inspection = {
    HistorySeconds = 10 * 60,
    HistoryCycleRatio = 0.25,
    -- Diagnostic comparison horizon only. It never produces chart samples.
    ForecastSeconds = 10 * 60,
    DiagnosisCycleRatio = 0.10,
    SampleSeconds = 30,
    CurveRefreshSeconds = 5,
    ValueRefreshSeconds = 1,
    MaxEtaSeconds = 24 * 60 * 60,
    MaxEtaCycles = 4,
    CloseDistance = 4.0,
    -- Standard GTA radar width plus a small breathing gap. Servers using a
    -- custom HUD can tune these values without changing the inspection UI.
    MinimapWidthRatio = 0.168,
    MinimapGapPixels = 18,
    RightInsetPixels = 18,
    SevereConditionPercent = 50,
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
    -- Independent budget for spatial snapshot requests.
    SubscriptionBucket = {
        capacity = 3,
        refillPerSecond = 1,
    },
    -- Checkpoints carry bounded interaction evidence and use an independent
    -- budget so they cannot exhaust ordinary farming or subscription actions.
    MinigameBucket = {
        capacity = 6,
        refillPerSecond = 2,
    },
    -- Avoid one console/webhook entry per packet during a flood.
    RateLimitLogInterval = 5000,
    -- Public farming exists only in the world bucket for the MVP.
    AllowedRoutingBuckets = { 0 },
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
    fertilize = 750,
    weed = 750,
    treat_pest = 750,
}

-- ---------------------------------------------------------------------------
-- Farming rules (Stage 3)
-- ---------------------------------------------------------------------------
Config.Farming = {
    -- New crops use the normalized biological clock. Existing records without
    -- simulationVersion remain on the immutable V1 evaluator.
    NewCropSimulationVersion = 2,
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
        weed = 'hand_hoe',
    },
    ConditionEffects = {
        Nutrients = true,
        Weeds = true,
        Pests = true,
    },
    AdvancedCare = {
        WaterDeficitThreshold = 35,
        CriticalStressMultiplier = 1.75,
        WeedWaterCompetition = 0.65,
        WeedNutrientCompetition = 0.8,
        PestWeedAcceleration = 1.0,
        PestGrowthPerHour = 200,
        PestDamagePerHour = 16,
        NutrientHealthLossPerHour = 8,
        GrowthPenaltyPerDeficitHour = {
            water = 0.35,
            nutrients = 0.45,
        },
        StressPerDeficitHour = {
            water = 12,
            nutrients = 14,
        },
        MinimumWeedCover = 8,
        MinimumPestPressure = 8,
        Cycle = {
            GreenGrowthBonus = 0.20,
            WatchGrowthPenalty = 0.10,
            CriticalGrowthPenalty = 0.55,
            WatchStressMultiplier = 0.35,
            DryHealthLossPerCycle = 1200,
            NutrientHealthLossPerCycle = 160,
            PestDamagePerCycle = 200,
            StressPerCycle = { water = 100, nutrients = 110 },
            WeedWaterCompetition = 0.35,
            WeedNutrientCompetition = 0.45,
            PestWeedAcceleration = 0.60,
            Water = { green = 60, critical = 35 },
            Pressure = { green = 20, critical = 50 },
            NutrientWatchMargin = 20,
        },
    },
    -- A minigame is cancelled when the ped loses at least this much health
    -- during one active interaction. Death always cancels regardless.
    MinigameDamageThreshold = 15,
}

-- ---------------------------------------------------------------------------
-- Company Supplies and Warehouse (0.3.0)
-- ---------------------------------------------------------------------------
Config.Supplies = {
    Ace = 'sonar_farm.company_admin',
    DraftTtlSeconds = 10 * 60,
    MaxDraftLines = 10,
    MaxLineQuantity = 99,
    SupplierFeeRate = 0.05,
    MonthlyBudget = 12000,
    BootstrapTreasury = 25000,
    ProcurementLimit = 1500,
    DeliveryWorkerSeconds = 30,
    UsageRecoveryGraceSeconds = 2,
    SessionTtlSeconds = 10 * 60,
    InteractionDistance = 3.0,
    TabletCommand = 'farmtablet',
    TabletKey = 'F7',
    Office = { coords = vec3(2448.38, 4977.18, 46.81), radius = 1.5 },
    Warehouse = { coords = vec3(2441.84, 4968.77, 46.81), radius = 1.8 },
    SupplierStock = {
        plus = { capacity = 20, restockAmount = 5, restockSeconds = 30 * 60 },
        pro = { capacity = 10, restockAmount = 2, restockSeconds = 60 * 60 },
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
    -- Share of the skill component inherited from authoritative planting.
    PlantingInfluence = 0.3,
    DefectWeight = 0.45,
    ProductionWeights = {
        nutrientStress = 0.55,
        pestDamage = 0.8,
    },
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
    -- Shared V2 condition math is cached briefly because ox_target evaluates
    -- every visible option repeatedly. Server actions never use this cache.
    InteractionCacheMs = 750,
    -- Crop models only need reevaluation when a visual stage can have changed.
    -- Each crop gets deterministic jitter to avoid a periodic all-field spike.
    VisualStageCacheMs = 5000,
    VisualStageJitterMs = 1500,
}

Config.Fields = {
    Ace = 'sonar_farm.fields_admin',
    InteractionDistance = 3.0,
    DetailRefreshSeconds = 5,
    MaxEventsPerDetail = 100,
    MinimumSlotSpacing = 0.75,
    PurchaseDraftTtlSeconds = 10 * 60,
    BuyerOrderWorkerSeconds = 60,
    BuyerOrderTemplates = {
        { id = 'local_carrots', buyer = 'Grapeseed Grocers', product = 'carrot',
          quantity = 40, minimumQuality = 70, intervalSeconds = 60 * 60,
          deadlineSeconds = 45 * 60, payout = 2200,
          destination = { label = 'Grapeseed Produce Depot', coords = vec3(1688.4, 4929.2, 42.1) } },
    },
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
