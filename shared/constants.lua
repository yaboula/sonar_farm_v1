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

-- Networked event names. Prefixed to avoid collisions with other resources.
Constants.EVENTS = {
    BRIDGE_READY = 'sonar_farm:bridgeReady',
}

-- ox_lib notification types.
Constants.NOTIFY = {
    INFO = 'inform',
    SUCCESS = 'success',
    WARNING = 'warning',
    ERROR = 'error',
}

Sonar.Constants = Constants
