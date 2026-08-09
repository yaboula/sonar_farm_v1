fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sonar_farm'
author 'Sonar'
description 'Scalable, server-authoritative farming platform for FiveM (QB-Core + ox).'
version '0.2.0'
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
    'shared/conditions.lua',
    -- Growth and physiology are shared so the client can predict what it renders
    -- with the exact same formula the server validates with.
    'shared/growth.lua',
    'shared/physiology.lua',
    -- Zone/slot resolver: same list on client (targets) and server (validation).
    'shared/zones.lua',
    'shared/config_validation.lua',
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
    'server/modules/runtime/runtime.lua',
    'server/modules/admin/permissions.lua',
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
    'server/modules/minigames/tomato_plant_scoring.lua',
    'server/modules/minigames/sessions.lua',
    'server/modules/farming/plant.lua',
    'server/modules/farming/care.lua',
    'server/modules/farming/cultivation.lua',
    'server/modules/farming/harvest.lua',
    'server/modules/debug/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    -- Render layer: generic pool first, then the crop logic that uses it.
    'client/modules/render/pool.lua',
    'client/modules/render/crops.lua',
    'client/modules/render/target.lua',
    -- Actions before sync/slots: those bind to Actions on select.
    'client/modules/interaction/actions.lua',
    'client/modules/minigames/controller.lua',
    'client/modules/zones/slots.lua',
    'client/modules/sync/client.lua',
    'client/modules/zones/blips.lua',
    'client/modules/admin/permissions.lua',
    'client/modules/admin/zone_builder.lua',
    'client/modules/admin/slot_builder.lua',
    'client/modules/debug/commands.lua',
}

-- Stage 5 minigames own the resource's single NUI page. The Business Hub stays
-- isolated in `web/` until the two surfaces receive an explicit shared shell.
ui_page 'minigames-ui/dist/index.html'
files {
    'minigames-ui/dist/index.html',
    'minigames-ui/dist/assets/**/*',
    'minigames-ui/dist/contracts/**/*',
}
