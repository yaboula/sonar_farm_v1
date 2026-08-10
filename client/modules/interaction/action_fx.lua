--[[
    sonar_farm - Field action feedback (client)
    Animations, PTFX and 3D sounds for plant/care/harvest. Presentation only:
    never decides yield, quality or crop state.

    Local player: runs for the whole progress duration.
    Nearby players: short burst after the public server event is rebroadcast.
]]

ActionFx = ActionFx or {}

local EVENTS = Sonar.Constants.EVENTS

-- Longer than the old placeholder bars so actions read as real field work.
local DURATION = {
    plant = 4500,
    water = 5200,
    fertilize = 4200,
    weed = 4800,
    treat_pest = 4500,
    harvest = 4800,
}

-- One anim set per action (not tiered). Kneeling / pouring / spraying / pulling.
local ANIM = {
    plant = {
        dict = 'amb@world_human_gardener_plant@male@base',
        clip = 'base',
        flag = 1,
    },
    water = {
        dict = 'timetable@gardener@filling_can',
        clip = 'gar_ig_5_filling_can',
        flag = 1,
    },
    fertilize = {
        dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@',
        clip = 'weed_crouch_checkingleaves_idle_01_inspector',
        flag = 1,
    },
    weed = {
        dict = 'amb@world_human_gardener_plant@male@idle_a',
        clip = 'idle_a',
        flag = 1,
    },
    treat_pest = {
        dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@',
        clip = 'weed_spraybottle_stand_spraying_01_inspector',
        flag = 49,
    },
    harvest = {
        dict = 'mini@repair',
        clip = 'fixing_a_ped',
        flag = 1,
    },
}

-- Client-only particles. Same look for every tool tier.
local PTFX = {
    plant = { asset = 'core', name = 'ent_dst_dust', scale = 0.9, z = 0.05 },
    water = { asset = 'core', name = 'ent_sht_water', scale = 1.1, z = 0.35 },
    fertilize = { asset = 'core', name = 'ent_dst_dust', scale = 0.75, z = 0.2 },
    weed = { asset = 'core', name = 'ent_dst_dust', scale = 0.85, z = 0.05 },
    treat_pest = { asset = 'core', name = 'ent_sht_steam', scale = 0.85, z = 0.55 },
    harvest = { asset = 'core', name = 'ent_dst_dust', scale = 1.0, z = 0.1 },
}

local SOUND = {
    plant = { name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', range = 12.0 },
    water = { name = 'SPRAY', set = 'CARWASH_SOUNDS', range = 16.0 },
    fertilize = { name = 'SPRAY', set = 'CARWASH_SOUNDS', range = 14.0 },
    weed = { name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', range = 12.0 },
    treat_pest = { name = 'SPRAY', set = 'CARWASH_SOUNDS', range = 16.0 },
    harvest = { name = 'PICK_UP_WEAPON', set = 'HUD_FRONTEND_CUSTOM_SOUNDSET', range = 14.0 },
}

local REMOTE_BURST_MS = 1600
local LOCAL_PTFX_INTERVAL = 380
local LOCAL_SOUND_INTERVAL = 1100
local ASSET_TIMEOUT = 1500

local loadedAssets = {}

---@param asset string
---@return boolean
local function ensurePtfxAsset(asset)
    if loadedAssets[asset] then return true end
    if HasNamedPtfxAssetLoaded(asset) then
        loadedAssets[asset] = true
        return true
    end

    RequestNamedPtfxAsset(asset)
    local deadline = GetGameTimer() + ASSET_TIMEOUT
    while not HasNamedPtfxAssetLoaded(asset) do
        if GetGameTimer() >= deadline then
            return false
        end
        Wait(0)
    end
    loadedAssets[asset] = true
    return true
end

---@param action string
---@param x number
---@param y number
---@param z number
local function playSound(action, x, y, z)
    local sound = SOUND[action]
    if not sound then return end
    PlaySoundFromCoord(-1, sound.name, x, y, z, sound.set, false, sound.range or 12.0, false)
end

---@param action string
---@param x number
---@param y number
---@param z number
local function playPtfxBurst(action, x, y, z)
    local fx = PTFX[action]
    if not fx then return end
    if not ensurePtfxAsset(fx.asset) then return end

    UseParticleFxAssetNextCall(fx.asset)
    StartParticleFxNonLoopedAtCoord(
        fx.name,
        x, y, z + (fx.z or 0.0),
        0.0, 0.0, 0.0,
        fx.scale or 1.0,
        false, false, false
    )
end

---@param coords table|vector3|nil
---@return number|nil, number|nil, number|nil
local function unpackCoords(coords)
    if not coords then return nil end
    local x = coords.x or coords[1]
    local y = coords.y or coords[2]
    local z = coords.z or coords[3]
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
        return nil
    end
    return x, y, z
end

---@param action string
---@return number
function ActionFx.Duration(action)
    return DURATION[action] or 4000
end

---@param action string
---@return table|nil
function ActionFx.Anim(action)
    local anim = ANIM[action]
    if not anim then return nil end
    return {
        dict = anim.dict,
        clip = anim.clip,
        flag = anim.flag,
    }
end

--- Continuous local feedback while the player works the plot.
---@param action string
---@param coords table|vector3|nil
---@return table|nil session
function ActionFx.Begin(action, coords)
    local x, y, z = unpackCoords(coords)
    if not action or not x then return nil end

    local session = {
        action = action,
        x = x,
        y = y,
        z = z,
        active = true,
    }

    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, x, y, z, 600)

    CreateThread(function()
        local nextPtfx = 0
        local nextSound = 0
        while session.active do
            local now = GetGameTimer()
            if now >= nextPtfx then
                playPtfxBurst(action, x, y, z)
                nextPtfx = now + LOCAL_PTFX_INTERVAL
            end
            if now >= nextSound then
                playSound(action, x, y, z)
                nextSound = now + LOCAL_SOUND_INTERVAL
            end
            Wait(50)
        end
    end)

    return session
end

---@param session table|nil
function ActionFx.Stop(session)
    if session then
        session.active = false
    end
end

--- Short burst for nearby observers after a successful action.
---@param action string
---@param coords table|vector3
function ActionFx.PlayRemote(action, coords)
    local x, y, z = unpackCoords(coords)
    if not action or not x then return end

    CreateThread(function()
        local endsAt = GetGameTimer() + REMOTE_BURST_MS
        local nextPtfx = 0
        playSound(action, x, y, z)
        while GetGameTimer() < endsAt do
            local now = GetGameTimer()
            if now >= nextPtfx then
                playPtfxBurst(action, x, y, z)
                nextPtfx = now + LOCAL_PTFX_INTERVAL
            end
            Wait(50)
        end
    end)
end

RegisterNetEvent(EVENTS.ACTION_FX, function(payload)
    if type(payload) ~= 'table' then return end
    local action = payload.action
    local x, y, z = tonumber(payload.x), tonumber(payload.y), tonumber(payload.z)
    if not action or not x or not y or not z then return end

    -- Actor already played local FX during progress.
    if tonumber(payload.source) == GetPlayerServerId(PlayerId()) then
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local dx = coords.x - x
    local dy = coords.y - y
    local dz = coords.z - z
    if (dx * dx + dy * dy + dz * dz) > (45.0 * 45.0) then
        return
    end

    ActionFx.PlayRemote(action, { x = x, y = y, z = z })
end)
