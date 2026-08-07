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
    'server/modules/state/growth.lua',
    'server/modules/state/state.lua',
    'server/modules/debug/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

-- NUI SPA (React + Vite + Tailwind). Enabled from Stage 9.
-- ui_page 'web/build/index.html'
-- files {
--     'web/build/index.html',
--     'web/build/**/*',
-- }
