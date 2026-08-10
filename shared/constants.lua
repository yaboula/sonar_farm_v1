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
    PLANTING = 'planting',
    PLANTING_FAILED = 'planting_failed',
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
    FERTILIZE = 'fertilize',
    WEED = 'weed',
    TREAT_PEST = 'treat_pest',
}

-- ox_lib callback names (client intent -> authoritative server handler).
Constants.CALLBACKS = {
    PLANT = 'sonar_farm:plant',
    WATER = 'sonar_farm:water',
    HARVEST = 'sonar_farm:harvest',
    FERTILIZE = 'sonar_farm:fertilize',
    WEED = 'sonar_farm:weed',
    TREAT_PEST = 'sonar_farm:treatPest',
    CARE_OPTIONS = 'sonar_farm:careOptions',
    INSPECT = 'sonar_farm:inspect',
    HUB_OPEN = 'sonar_farm:hub:open',
    HUB_LOAD = 'sonar_farm:hub:load',
    HUB_DISPATCH = 'sonar_farm:hub:dispatch',
    HUB_SUBSCRIBE_FIELD = 'sonar_farm:hub:subscribeField',
    HUB_CLOSE = 'sonar_farm:hub:close',
    MINIGAME_BEGIN = 'sonar_farm:minigame:begin',
    MINIGAME_CHECKPOINT = 'sonar_farm:minigame:checkpoint',
    MINIGAME_CANCEL = 'sonar_farm:minigame:cancel',
    MINIGAME_RESUME = 'sonar_farm:minigame:resume',
    MINIGAME_CLEAR_INCOMPLETE = 'sonar_farm:minigame:clearIncomplete',
    SUBSCRIBE = 'sonar_farm:subscribe',
    ADMIN_AUTHORIZED = 'sonar_farm:adminAuthorized',
    FIELD_DRAFT_SAVE = 'sonar_farm:fieldDraftSave',
}

-- Networked event names. Prefixed to avoid collisions with other resources.
Constants.EVENTS = {
    BRIDGE_READY = 'sonar_farm:bridgeReady',
    -- Server -> client render deltas (Stage 4). Sent only to the players
    -- subscribed to the affected spatial cell.
    CROP_SYNC = 'sonar_farm:cropSync',
    CROP_REMOVE = 'sonar_farm:cropRemove',
    SYNC_RESET = 'sonar_farm:syncReset',
    RUNTIME_READY = 'sonar_farm:runtimeReady',
    FIELD_DELTA = 'sonar_farm:fieldDelta',
}

-- Public server events other resources can listen to (platform API).
Constants.PUBLIC_EVENTS = {
    CROP_PLANTED = 'sonar_farm:cropPlanted',
    CROP_WATERED = 'sonar_farm:cropWatered',
    CROP_HARVESTED = 'sonar_farm:cropHarvested',
    CROP_FERTILIZED = 'sonar_farm:cropFertilized',
    CROP_WEEDED = 'sonar_farm:cropWeeded',
    CROP_TREATED = 'sonar_farm:cropTreated',
}

-- Machine-readable rejection reasons returned by server handlers. The client
-- maps these to user-facing text; never build player messages on the server.
Constants.REJECT = {
    RATE_LIMITED = 'rate_limited',
    SERVICE_UNAVAILABLE = 'service_unavailable',
    PLAYER_NOT_READY = 'player_not_ready',
    WRONG_INSTANCE = 'wrong_instance',
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
    NUTRIENTS_SATURATED = 'nutrients_saturated',
    NO_WEEDS_DETECTED = 'no_weeds_detected',
    NO_PEST_DETECTED = 'no_pest_detected',
    CONDITION_DISABLED = 'condition_disabled',
    MINIGAME_REQUIRED = 'minigame_required',
    MINIGAME_DISABLED = 'minigame_disabled',
    MINIGAME_SESSION_NOT_FOUND = 'minigame_session_not_found',
    MINIGAME_SESSION_EXPIRED = 'minigame_session_expired',
    MINIGAME_INVALID_STEP = 'minigame_invalid_step',
    MINIGAME_INVALID_TRACE = 'minigame_invalid_trace',
    PLANTING_INCOMPLETE = 'planting_incomplete',
    PLANTING_NOT_FAILED = 'planting_not_failed',
    INTERNAL_ERROR = 'internal_error',
    INVALID_ITEM = 'invalid_item',
}

-- ox_lib notification types.
Constants.NOTIFY = {
    INFO = 'inform',
    SUCCESS = 'success',
    WARNING = 'warning',
    ERROR = 'error',
}

Sonar.Constants = Constants
