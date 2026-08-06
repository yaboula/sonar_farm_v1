--[[
    sonar_farm - Logger (server)
    Structured, level-based logging with decoupled connectors. Business code
    calls Logger.Info / Logger.Warn / Logger.Exploit and never worries about
    where logs go (console now; Discord / DB connectors wired here).

    Levels: INFO < WARN < EXPLOIT (see Sonar.Constants.LOG_LEVELS).
]]

Logger = Logger or {}

local LEVELS = Sonar.Constants.LOG_LEVELS
local PREFIX = '^5[sonar_farm]^7'

-- Console colors per level.
local LEVEL_COLOR = {
    INFO = '^2',
    WARN = '^3',
    EXPLOIT = '^1',
}

-- ---------------------------------------------------------------------------
-- Connectors (decoupled sinks). Each takes a structured entry.
-- Extra connectors (DB) are wired in Stage 3 when persistence exists.
-- ---------------------------------------------------------------------------
local connectors = {}

--- Console connector: respects Config.Logging.ConsoleLevel threshold.
local function consoleConnector(entry)
    local threshold = LEVELS[Config.Logging.ConsoleLevel] or LEVELS.INFO
    if LEVELS[entry.level] < threshold then return end

    local color = LEVEL_COLOR[entry.level] or '^7'
    local category = entry.category and ('[' .. entry.category .. '] ') or ''
    print(('%s %s[%s]^7 %s%s'):format(PREFIX, color, entry.level, category, entry.message))

    if entry.data and Config.Debug then
        print(('%s   ^7data: %s'):format(PREFIX, json.encode(entry.data)))
    end
end

--- Discord connector: posts WARN/EXPLOIT to a webhook when enabled.
local function discordConnector(entry)
    if not Config.Features.Discord then return end
    local webhook = Config.Logging.DiscordWebhook
    if not webhook or webhook == '' then return end
    if LEVELS[entry.level] < LEVELS.WARN then return end

    local colorMap = { WARN = 16776960, EXPLOIT = 16711680 }
    local payload = {
        username = 'sonar_farm',
        embeds = {
            {
                title = ('%s%s'):format(entry.level, entry.category and (' - ' .. entry.category) or ''),
                description = entry.message,
                color = colorMap[entry.level] or 3066993,
                fields = entry.data and {
                    { name = 'data', value = ('```json\n%s\n```'):format(json.encode(entry.data)) },
                } or nil,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            },
        },
    }

    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json',
    })
end

connectors[#connectors + 1] = consoleConnector
connectors[#connectors + 1] = discordConnector

-- ---------------------------------------------------------------------------
-- Core dispatch
-- ---------------------------------------------------------------------------
local function dispatch(level, category, message, data)
    local entry = {
        level = level,
        category = category,
        message = message,
        data = data,
        timestamp = os.time(),
    }
    for _, connector in ipairs(connectors) do
        local ok, err = pcall(connector, entry)
        if not ok then
            print(('%s ^1[LOGGER]^7 connector error: %s'):format(PREFIX, tostring(err)))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Informational log.
---@param message string
---@param category? string
---@param data? table
function Logger.Info(message, category, data)
    dispatch('INFO', category, message, data)
end

--- Warning log.
---@param message string
---@param category? string
---@param data? table
function Logger.Warn(message, category, data)
    dispatch('WARN', category, message, data)
end

--- Exploit / security log. Always meant to be actioned.
---@param message string
---@param category? string
---@param data? table
function Logger.Exploit(message, category, data)
    dispatch('EXPLOIT', category, message, data)
end

--- Register an additional connector (e.g. the DB sink in Stage 3).
---@param connector fun(entry: table)
function Logger.RegisterConnector(connector)
    connectors[#connectors + 1] = connector
end
