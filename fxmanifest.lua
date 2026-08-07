fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sonar_farm'
author 'Sonar'
description 'Scalable, server-authoritative farming platform for FiveM (QB-Core + ox).'
version '0.1.0'
repository 'https://github.com/yaboula/sonar_farm_v1.git'

-- Hard dependencies. The Bridge auto-detects the framework at runtime.
dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    -- Configuration must load first: everything else reads from `Config`.
    'config/config.lua',
    'config/crops.lua',
    'config/zones.lua',
    'config/minigames.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/time.lua',
    -- Growth and physiology are shared so the client can predict what it renders
    -- with the exact same formula the server validates with.
    'shared/growth.lua',
    'shared/physiology.lua',
    -- Bridge Layer (framework abstraction). Order matters:
    -- core first, then adapters register themselves into the registry.
    'bridge/bridge.lua',
    'bridge/frameworks/qbcore.lua',
    'bridge/frameworks/esx.lua',
    'bridge/frameworks/qbox.lua',
    'bridge/inventory/ox_inventory.lua',
    'bridge/target/ox_target.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/modules/logger/logger.lua',
    'server/modules/database/database.lua',
    'server/modules/state/state.lua',
    -- Security before farming: actions depend on these guards.
    'server/modules/security/ratelimit.lua',
    'server/modules/security/validation.lua',
    -- Sync after validation (it reads the authoritative player position) and
    -- before farming (the action handlers emit deltas through it).
    'server/modules/sync/subscriptions.lua',
    -- Farming: shared helpers first, then one file per action.
    'server/modules/farming/lock.lua',
    'server/modules/farming/physiology.lua',
    'server/modules/farming/quality.lua',
    'server/modules/farming/plant.lua',
    'server/modules/farming/care.lua',
    'server/modules/farming/harvest.lua',
    'server/modules/farming/query.lua',
    'server/modules/debug/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    -- Render layer: generic pool first, then the crop logic that uses it.
    'client/modules/render/pool.lua',
    'client/modules/render/crops.lua',
    'client/modules/render/target.lua',
    -- Actions before sync: the sync thread registers target zones that bind to
    -- Actions on select.
    'client/modules/interaction/actions.lua',
    'client/modules/sync/client.lua',
    'client/modules/zones/blips.lua',
    'client/modules/debug/commands.lua',
}

-- NUI SPA (React + Vite + Tailwind). Enabled from Stage 9.
-- ui_page 'web/build/index.html'
-- files {
--     'web/build/index.html',
--     'web/build/**/*',
-- }
