--[[
    sonar_farm - Shared constants
    Single source of truth for enums, event names and magic values used across
    client and server. Namespaced under the global `Sonar` table.
]]

Sonar = Sonar or {}

local Constants = {}

-- Resource identity.
Constants.RESOURCE = GetCurrentResourceName()

-- Spatial-hash cell size in meters. Used to compute a crop's "gx:gy" cell key
-- for the streaming/culling grid (Stage 4). Default matches config zone cells.
Constants.SPATIAL_CELL_SIZE = 100

-- Log severity levels. Ordered for threshold comparisons (see logger).
Constants.LOG_LEVELS = {
    INFO = 1,
    WARN = 2,
    EXPLOIT = 3,
}

-- Supported frameworks (Bridge adapters).
Constants.FRAMEWORKS = {
    QBCORE = 'qb-core',
    ESX = 'esx',
    QBOX = 'qbox',
}

-- Crop lifecycle states (used from Stage 3+).
Constants.CROP_STATE = {
    PLANTED = 'planted',
    GROWING = 'growing',
    MATURE = 'mature',
    WITHERED = 'withered',
    DEAD = 'dead',
}

-- Product quality tiers, mapped from a 0..100 quality score (Stage 8).
Constants.QUALITY_TIERS = {
    { key = 'poor', min = 0, label = 'Poor' },
    { key = 'standard', min = 40, label = 'Standard' },
    { key = 'fine', min = 70, label = 'Fine' },
    { key = 'premium', min = 90, label = 'Premium' },
}

-- Player-initiated farming actions. Used for cooldowns, rate limiting and
-- quality providers.
Constants.ACTIONS = {
    PLANT = 'plant',
    WATER = 'water',
    HARVEST = 'harvest',
}

-- ox_lib callback names (client intent -> authoritative server handler).
Constants.CALLBACKS = {
    PLANT = 'sonar_farm:plant',
    WATER = 'sonar_farm:water',
    HARVEST = 'sonar_farm:harvest',
    NEARBY = 'sonar_farm:nearby',
    SUBSCRIBE = 'sonar_farm:subscribe',
}

-- Networked event names. Prefixed to avoid collisions with other resources.
Constants.EVENTS = {
    BRIDGE_READY = 'sonar_farm:bridgeReady',
    -- Server -> client render deltas (Stage 4). Sent only to the players
    -- subscribed to the affected spatial cell.
    CROP_SYNC = 'sonar_farm:cropSync',
    CROP_REMOVE = 'sonar_farm:cropRemove',
}

-- Public server events other resources can listen to (platform API).
Constants.PUBLIC_EVENTS = {
    CROP_PLANTED = 'sonar_farm:cropPlanted',
    CROP_WATERED = 'sonar_farm:cropWatered',
    CROP_HARVESTED = 'sonar_farm:cropHarvested',
}

-- Machine-readable rejection reasons returned by server handlers. The client
-- maps these to user-facing text; never build player messages on the server.
Constants.REJECT = {
    RATE_LIMITED = 'rate_limited',
    COOLDOWN = 'cooldown',
    TOO_FAR = 'too_far',
    SUSPICIOUS_MOVEMENT = 'suspicious_movement',
    NOT_IN_ZONE = 'not_in_zone',
    CROP_NOT_ALLOWED_HERE = 'crop_not_allowed_here',
    -- Slot system: the requested plot does not exist in config, or something is
    -- already growing in it (the client's view was stale).
    SLOT_NOT_FOUND = 'slot_not_found',
    SLOT_OCCUPIED = 'slot_occupied',
    UNKNOWN_CROP = 'unknown_crop',
    MISSING_SEED = 'missing_seed',
    MISSING_TOOL = 'missing_tool',
    CROP_NOT_FOUND = 'crop_not_found',
    CROP_NOT_MATURE = 'crop_not_mature',
    CROP_DEAD = 'crop_dead',
    NOT_OWNER = 'not_owner',
    CROP_LIMIT_REACHED = 'crop_limit_reached',
    INVENTORY_FULL = 'inventory_full',
    ALREADY_IN_PROGRESS = 'already_in_progress',
    ALREADY_WATERED = 'already_watered',
    INTERNAL_ERROR = 'internal_error',
}

-- ox_lib notification types.
Constants.NOTIFY = {
    INFO = 'inform',
    SUCCESS = 'success',
    WARNING = 'warning',
    ERROR = 'error',
}

Sonar.Constants = Constants
