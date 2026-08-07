--[[
    sonar_farm - In-Game Slot Builder (Admin Tool)
    Point-by-point zone designer. Places individual slots by clicking on the ground.

    Generates the `slots` table for config/zones.lua — ideal for irregular fields,
    small patches or any zone that cannot be captured with a rectangular grid.

    Usage: /farm_slots
    Controls (all shown in the on-screen UI):
      LEFT CLICK  Place a slot at the ground hit with the camera heading baked in.
      RIGHT CLICK Remove the nearest placed slot (undo-like, precise).
      TAB         Toggle between Walk mode (player moves) and Place mode (WASD disabled).
      H           Capture the current camera heading and apply it to the next click.
      G           Open a manual-input dialog to type exact coordinates for a slot.
      C           Clear all slots with a confirmation prompt.
      ENTER       Finalize: name the zone and copy the config block to the clipboard.
      BACKSPACE   Cancel without saving.

    Output format (mirrors what shared/zones.lua expects in `zone.slots`):
        slots = {
            { x = 100.00, y = 200.00, z = 30.10, heading = 0.0   },
            { x = 102.50, y = 200.00, z = 30.20, heading = 45.0  },
        },
]]

local SB_IDLE    = 0
local SB_PLACING = 1

local sbState      = SB_IDLE
local sbSlots      = {}          -- array of { x, y, z, heading }
local sbWalkMode   = false       -- false = Place/Nudge (WASD disabled), true = Walk
local sbNextHeading = nil        -- heading locked by pressing H; nil = use camera

-- ─── Shared Raycast Utilities ────────────────────────────────────────────────

local function SB_RotationToDirection(rotation)
    local r = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    return {
        x = -math.sin(r.z) * math.abs(math.cos(r.x)),
        y =  math.cos(r.z) * math.abs(math.cos(r.x)),
        z =  math.sin(r.x)
    }
end

local function SB_RayCastCamera(distance)
    local rot   = GetGameplayCamRot(2)
    local coord = GetGameplayCamCoord()
    local dir   = SB_RotationToDirection(rot)
    local dest  = vec3(
        coord.x + dir.x * distance,
        coord.y + dir.y * distance,
        coord.z + dir.z * distance
    )
    local _, hit, endCoords = GetShapeTestResult(
        StartShapeTestRay(coord.x, coord.y, coord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    )
    return hit, endCoords
end

local function SB_RayCastGround(x, y, z)
    local _, hit, endCoords = GetShapeTestResult(
        StartShapeTestRay(x, y, z + 50.0, x, y, z - 50.0, -1, PlayerPedId(), 0)
    )
    return (hit == 1) and endCoords.z or z
end

-- ─── UI ──────────────────────────────────────────────────────────────────────

local function SB_ShowUI()
    if sbState ~= SB_PLACING then return end

    local headingStr = sbNextHeading
        and string.format('%.1f° (locked)', sbNextHeading)
        or  'Camera'

    local modeStr = sbWalkMode and '🚶 Walk' or '📍 Place'

    local text = string.format(
        '**Slot Builder** — %d slot(s)  \n' ..
        '[LEFT CLICK] Place Slot (heading: %s)  \n' ..
        '[RIGHT CLICK] Remove Nearest  \n' ..
        '[H] Lock Camera Heading  \n' ..
        '[TAB] Mode: %s  \n' ..
        '[G] Manual Slot Input  \n' ..
        '[C] Clear All  \n' ..
        '[ENTER] Save  \n' ..
        '[BACKSPACE] Cancel',
        #sbSlots, headingStr, modeStr
    )
    lib.showTextUI(text, { position = 'top-center', icon = 'map-pin' })
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local MIN_SLOT_DIST = 0.5 -- metres; prevents stacking two slots on top of each other

local function SB_TooClose(pos)
    for _, s in ipairs(sbSlots) do
        local dx, dy = s.x - pos.x, s.y - pos.y
        if (dx * dx + dy * dy) < (MIN_SLOT_DIST * MIN_SLOT_DIST) then
            return true
        end
    end
    return false
end

local function SB_Centroid()
    if #sbSlots == 0 then return nil end
    local cx, cy, cz = 0, 0, 0
    for _, s in ipairs(sbSlots) do cx = cx + s.x; cy = cy + s.y; cz = cz + s.z end
    local n = #sbSlots
    return cx / n, cy / n, cz / n
end

local function SB_NearestSlotIndex(pos)
    local bestIdx, bestDist = nil, math.huge
    for i, s in ipairs(sbSlots) do
        local dx, dy = s.x - pos.x, s.y - pos.y
        local d = dx * dx + dy * dy
        if d < bestDist then bestDist = d; bestIdx = i end
    end
    return bestIdx, math.sqrt(bestDist)
end

-- ─── Export ──────────────────────────────────────────────────────────────────

local function SB_ExportToClipboard(zoneKey, label, allowedCrops)
    if #sbSlots == 0 then
        Bridge.Notify("No slots to export.", "error")
        return
    end

    -- Allowed crops string
    local cropsStr = ""
    if allowedCrops and #allowedCrops > 0 then
        local parts = {}
        for _, c in ipairs(allowedCrops) do parts[#parts + 1] = string.format("'%s'", c) end
        cropsStr = table.concat(parts, ", ")
    end

    -- Build slot lines
    local slotLines = {}
    for _, s in ipairs(sbSlots) do
        slotLines[#slotLines + 1] = string.format(
            "        { x = %.2f, y = %.2f, z = %.2f, heading = %.1f },",
            s.x, s.y, s.z, s.heading
        )
    end
    local slotsBlock = table.concat(slotLines, "\n")

    local cx, cy, cz = SB_Centroid()

    local output = string.format(
        "\n    %s = {\n" ..
        "        label        = '%s',\n" ..
        "        center       = vec3(%.2f, %.2f, %.2f),\n" ..
        "        allowedCrops = { %s },\n\n" ..
        "        slots = {\n%s\n        },\n\n" ..
        "        blip = { enabled = true, sprite = 496, color = 25, scale = 0.8 },\n" ..
        "    },\n",
        zoneKey, label, cx, cy, cz, cropsStr, slotsBlock
    )

    lib.setClipboard(output)
    print("\n^2[SONAR FARM] GENERATED SLOT ZONE CONFIGURATION:^0")
    print(output)
    Bridge.Notify(string.format("Zone '%s' (%d slots) copied to clipboard!", zoneKey, #sbSlots), "success")
end

-- ─── Finalize ────────────────────────────────────────────────────────────────

local function SB_Finalize()
    sbState = SB_IDLE
    lib.hideTextUI()

    if #sbSlots == 0 then
        Bridge.Notify("No slots placed. Nothing to save.", "error")
        return
    end

    local cropOptions = {}
    for cropKey, cropData in pairs(Config.Crops or {}) do
        cropOptions[#cropOptions + 1] = { value = cropKey, label = cropData.label }
    end
    table.sort(cropOptions, function(a, b) return a.label < b.label end)

    local input = lib.inputDialog('Save Slot Zone', {
        { type = 'input',        label = 'Zone Key',     placeholder = 'e.g. vineyard_west',  required = true },
        { type = 'input',        label = 'Display Label', placeholder = 'e.g. West Vineyard', required = true },
        { type = 'multi-select', label = 'Allowed Crops (Empty = All)', options = cropOptions },
    })

    if not input or not input[1] or not input[2] then
        Bridge.Notify("Slot Builder cancelled.", "error")
        return
    end

    SB_ExportToClipboard(input[1], input[2], input[3])
end

-- ─── DrawText3D (native; no tick overhead when builder is idle) ───────────────

local function SB_DrawLabel(x, y, z, text)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 100, 220)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(screenX, screenY)
end

-- ─── Main Render / Input Loop ─────────────────────────────────────────────────

local function SB_Loop()
    CreateThread(function()
        while sbState ~= SB_IDLE do
            Wait(0)

            -- Always block weapon-wheel and attack while builder is active
            DisableControlAction(0, 14,  true) -- weapon wheel left
            DisableControlAction(0, 15,  true) -- weapon wheel right
            DisableControlAction(0, 24,  true) -- attack (LEFT CLICK)
            DisableControlAction(0, 25,  true) -- aim   (RIGHT CLICK)
            DisableControlAction(0, 257, true) -- attack2

            -- In Place mode block movement so WASD doesn't move the character
            if not sbWalkMode then
                DisableControlAction(0, 32, true) -- W
                DisableControlAction(0, 33, true) -- S
                DisableControlAction(0, 34, true) -- A
                DisableControlAction(0, 35, true) -- D
            end

            -- ── Hover Preview ────────────────────────────────────────────────
            local hit, hitPos = SB_RayCastCamera(60.0)
            if hit == 1 then
                local tooClose = SB_TooClose(hitPos)
                local r, g, b = tooClose and 255 or 0, tooClose and 50 or 220, 0
                -- Hover: cylinder shows placement ghost, red if too close
                DrawMarker(1, hitPos.x, hitPos.y, hitPos.z,
                    0,0,0,  0,0,0,  0.35,0.35,0.05,
                    r, g, b, 140,
                    false, false, 2, false, nil, nil, false)
            end

            -- ── Draw Already-Placed Slots ─────────────────────────────────────
            for i, s in ipairs(sbSlots) do
                -- Amber cylinder for confirmed slots
                DrawMarker(1, s.x, s.y, s.z,
                    0,0,0,  0,0,0,  0.30,0.30,0.06,
                    255, 165, 0, 200,
                    false, false, 2, false, nil, nil, false)

                -- Small upward spike so they pop on uneven terrain
                DrawMarker(1, s.x, s.y, s.z + 0.3,
                    0,0,0,  0,0,0,  0.08,0.08,0.5,
                    255, 220, 50, 180,
                    false, false, 2, false, nil, nil, false)

                -- Index label above each slot
                SB_DrawLabel(s.x, s.y, s.z + 0.85, tostring(i))

                -- Line to next slot so you can see the order at a glance
                if sbSlots[i + 1] then
                    local n = sbSlots[i + 1]
                    DrawLine(s.x, s.y, s.z + 0.4, n.x, n.y, n.z + 0.4, 255, 200, 0, 160)
                end
            end

            -- ── Controls ──────────────────────────────────────────────────────
            local uiChanged = false

            -- TAB — toggle walk / place mode
            if IsControlJustPressed(0, 37) or IsDisabledControlJustPressed(0, 37) then
                sbWalkMode = not sbWalkMode
                uiChanged  = true
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            end

            -- H — lock current camera heading for next placement
            if IsControlJustPressed(0, 74) or IsDisabledControlJustPressed(0, 74) then
                local camHeading = GetGameplayCamRot(2).z
                -- Convert cam Z rotation to a game heading (0° = North, CW positive)
                sbNextHeading = (360.0 - camHeading) % 360.0
                uiChanged = true
                Bridge.Notify(string.format("Heading locked: %.1f°", sbNextHeading), "info")
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            end

            -- LEFT CLICK — place slot
            if IsDisabledControlJustPressed(0, 24) and hit == 1 then
                if SB_TooClose(hitPos) then
                    Bridge.Notify("Too close to an existing slot (min 0.5m).", "error")
                else
                    local h = sbNextHeading or ((360.0 - GetGameplayCamRot(2).z) % 360.0)
                    local z = SB_RayCastGround(hitPos.x, hitPos.y, hitPos.z)
                    sbSlots[#sbSlots + 1] = { x = hitPos.x, y = hitPos.y, z = z, heading = h }
                    uiChanged = true
                    PlaySoundFrontend(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", true)
                end
            end

            -- RIGHT CLICK — remove nearest placed slot
            if IsDisabledControlJustPressed(0, 25) then
                if #sbSlots > 0 and hit == 1 then
                    local idx, dist = SB_NearestSlotIndex(hitPos)
                    if idx and dist < 5.0 then
                        table.remove(sbSlots, idx)
                        uiChanged = true
                        Bridge.Notify(string.format("Slot %d removed.", idx), "error")
                        PlaySoundFrontend(-1, "CANCEL", "HUD_MINI_GAME_SOUNDSET", true)
                    else
                        Bridge.Notify("No slot within 5m to remove.", "error")
                    end
                end
            end

            -- G — manual coordinate input
            if IsControlJustPressed(0, 47) then
                lib.hideTextUI()
                local ped = PlayerPedId()
                local pedCoords = GetEntityCoords(ped)
                local input = lib.inputDialog('Add Slot Manually', {
                    { type = 'number', label = 'X',       default = pedCoords.x, required = true },
                    { type = 'number', label = 'Y',       default = pedCoords.y, required = true },
                    { type = 'number', label = 'Z',       default = pedCoords.z, required = true },
                    { type = 'number', label = 'Heading', default = sbNextHeading or 0.0, required = true, min = 0.0, max = 360.0, step = 0.1 },
                })
                if input then
                    local pos = { x = input[1], y = input[2], z = input[3] }
                    if SB_TooClose(pos) then
                        Bridge.Notify("Too close to an existing slot.", "error")
                    else
                        sbSlots[#sbSlots + 1] = { x = pos.x, y = pos.y, z = pos.z, heading = input[4] or 0.0 }
                        uiChanged = true
                        PlaySoundFrontend(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", true)
                    end
                end
                SB_ShowUI()
                uiChanged = false -- already refreshed above
            end

            -- C — clear all slots (requires confirmation)
            if IsControlJustPressed(0, 26) or IsDisabledControlJustPressed(0, 26) then -- C key
                if #sbSlots > 0 then
                    lib.hideTextUI()
                    local confirmed = lib.alertDialog({
                        header  = 'Clear All Slots',
                        content = string.format('This will delete all %d placed slots. Continue?', #sbSlots),
                        centered = true,
                        cancel  = true,
                    })
                    if confirmed == 'confirm' then
                        sbSlots   = {}
                        sbNextHeading = nil
                        uiChanged = true
                        Bridge.Notify("All slots cleared.", "error")
                        PlaySoundFrontend(-1, "CANCEL", "HUD_MINI_GAME_SOUNDSET", true)
                    end
                    SB_ShowUI()
                    uiChanged = false
                end
            end

            -- ENTER — save
            if IsControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 191) then
                if #sbSlots == 0 then
                    Bridge.Notify("Place at least one slot before saving.", "error")
                else
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    SB_Finalize()
                end
            end

            -- BACKSPACE / ESC — cancel
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                sbState = SB_IDLE
                lib.hideTextUI()
                Bridge.Notify("Slot Builder cancelled.", "error")
            end

            if uiChanged then SB_ShowUI() end
        end

        -- Clean exit: make sure UI is gone
        lib.hideTextUI()
    end)
end

-- ─── Command Entry-point ──────────────────────────────────────────────────────

RegisterCommand('farm_slots', function()
    if sbState ~= SB_IDLE then
        Bridge.Notify("Slot Builder is already active. Press BACKSPACE to cancel.", "error")
        return
    end

    sbSlots       = {}
    sbWalkMode    = false
    sbNextHeading = nil
    sbState       = SB_PLACING

    Bridge.Notify("Slot Builder active. LEFT CLICK to place slots.", "info")
    SB_ShowUI()
    SB_Loop()
end, false)
