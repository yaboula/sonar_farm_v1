--[[
    sonar_farm - In-Game Zone Builder (Admin Tool)
    Premium UX visualizer for creating grid zones in real-time.
]]

local Builder = {}

local STATE_IDLE = 0
local STATE_SELECT_ORIGIN = 1
local STATE_EDIT_GRID = 2

local state = STATE_IDLE
local gridMode = true
local grid = {}

-- Utility: Math for Camera Raycast
local function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

local function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot(2)
    local cameraCoord = GetGameplayCamCoord()
    local dir = RotationToDirection(cameraRotation)
    local dest = vec3(
        cameraCoord.x + dir.x * distance,
        cameraCoord.y + dir.y * distance,
        cameraCoord.z + dir.z * distance
    )
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(
        StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    )
    return hit, endCoords, entityHit
end

local function RayCastGround(x, y, z)
    local _, hit, endCoords = GetShapeTestResult(
        StartShapeTestRay(x, y, z + 50.0, x, y, z - 50.0, -1, PlayerPedId(), 0)
    )
    if hit == 1 then
        return endCoords.z
    end
    return z
end

-- Utility: Grid Calculation (Mirrors shared/zones.lua math)
local function rotate(lx, ly, heading)
    local rad = math.rad(heading or 0.0)
    local cos, sin = math.cos(rad), math.sin(rad)
    return (lx * cos) - (ly * sin), (lx * sin) + (ly * cos)
end

local function calculateGridSlots()
    local slots = {}
    local origin = grid.origin
    if not origin then return slots end

    local rows = math.max(1, math.floor(grid.rows or 1))
    local cols = math.max(1, math.floor(grid.cols or 1))
    local spacingX = grid.spacing.x or 2.0
    local spacingY = grid.spacing.y or 2.0
    local heading = grid.heading or 0.0

    local offsetX = ((cols - 1) * spacingX) / 2
    local offsetY = ((rows - 1) * spacingY) / 2

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local dx, dy = rotate((col * spacingX) - offsetX, (row * spacingY) - offsetY, heading)
            local posZ = RayCastGround(origin.x + dx, origin.y + dy, origin.z)
            slots[#slots + 1] = vec3(origin.x + dx, origin.y + dy, posZ)
        end
    end
    return slots
end

local function showInstructions()
    if state == STATE_SELECT_ORIGIN then
        lib.showTextUI('**Zone Builder**  \n[LEFT CLICK] Set Origin  \n[BACKSPACE] Cancel', {
            position = 'top-center',
            icon = 'crosshairs'
        })
    elseif state == STATE_EDIT_GRID then
        local text = string.format('**Zone Builder**  \n[LEFT CLICK] Reposition  \n[TAB] Mode: %s  \n[WASD] %s  \n[G] Manual Input  \n[UP/DOWN] Rows: %d  \n[LEFT/RIGHT] Cols: %d  \n[SCROLL] Spacing X: %.1f  \n[ALT+SCROLL] Spacing Y: %.1f  \n[Q/E] Heading: %.1f  \n[SHIFT] x5 Speed  \n[ENTER] Save  \n[BACKSPACE] Cancel', 
            gridMode and "Nudge" or "Walk", gridMode and "Nudge Origin" or "Move Player", grid.rows, grid.cols, grid.spacing.x, grid.spacing.y, grid.heading)
        lib.showTextUI(text, {
            position = 'top-center',
            icon = 'vector-square'
        })
    end
end

local function exportToClipboard(zoneKey, label, allowedCrops)
    local cropsStr = ""
    if allowedCrops and #allowedCrops > 0 then
        local parts = {}
        for _, crop in ipairs(allowedCrops) do
            parts[#parts + 1] = string.format("'%s'", crop)
        end
        cropsStr = table.concat(parts, ", ")
    end

    local output = string.format([[
    %s = {
        label = '%s',
        center = vec3(%.2f, %.2f, %.2f),
        allowedCrops = { %s },
        
        grid = {
            origin = vec3(%.2f, %.2f, %.2f),
            rows = %d,
            cols = %d,
            spacing = { x = %.2f, y = %.2f },
            heading = %.1f,
        },
        
        blip = {
            enabled = true,
            sprite = 496,
            color = 25,
            scale = 0.8,
        },
    },
]], zoneKey, label, grid.origin.x, grid.origin.y, grid.origin.z, cropsStr, grid.origin.x, grid.origin.y, grid.origin.z, grid.rows, grid.cols, grid.spacing.x, grid.spacing.y, grid.heading)
    
    lib.setClipboard(output)
    print("\n^2[SONAR FARM] GENERATED ZONE CONFIGURATION:^0")
    print(output)
    Bridge.Notify("Zone config copied to clipboard!", "success")
end

local function finalizeZone()
    state = STATE_IDLE
    lib.hideTextUI()

    local cropOptions = {}
    for cropKey, cropData in pairs(Config.Crops or {}) do
        cropOptions[#cropOptions + 1] = { value = cropKey, label = cropData.label }
    end
    table.sort(cropOptions, function(a, b) return a.label < b.label end)

    local input = lib.inputDialog('Save Zone Configuration', {
        { type = 'input', label = 'Zone Key', placeholder = 'e.g. grapeseed_new', required = true },
        { type = 'input', label = 'Display Label', placeholder = 'e.g. Grapeseed Fields', required = true },
        { type = 'multi-select', label = 'Allowed Crops (Empty = All)', options = cropOptions }
    })

    if not input or not input[1] or not input[2] then
        Bridge.Notify("Zone Builder cancelled.", "error")
        return
    end

    exportToClipboard(input[1], input[2], input[3])
end

local function startEditLoop()
    CreateThread(function()
        while state ~= STATE_IDLE do
            Wait(0)
            
            if state == STATE_SELECT_ORIGIN then
                local hit, hitPos = RayCastGamePlayCamera(50.0)
                if hit == 1 then
                    DrawMarker(28, hitPos.x, hitPos.y, hitPos.z, 0,0,0, 0,0,0, 0.3,0.3,0.3, 0,255,0,150, false, false, 2, false, nil, nil, false)
                    
                    DisableControlAction(0, 24, true) -- Attack
                    if IsDisabledControlJustPressed(0, 24) then
                        grid.origin = hitPos
                        state = STATE_EDIT_GRID
                        showInstructions()
                        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    end
                end

            elseif state == STATE_EDIT_GRID then
                DisableControlAction(0, 14, true)
                DisableControlAction(0, 15, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 257, true)
                
                if gridMode then
                    DisableControlAction(0, 32, true) -- W
                    DisableControlAction(0, 33, true) -- S
                    DisableControlAction(0, 34, true) -- A
                    DisableControlAction(0, 35, true) -- D
                end
                
                local changed = false
                local shiftPos = IsControlPressed(0, 21) -- LSHIFT
                local altPos = IsControlPressed(0, 19)   -- LALT

                local rowColStep = shiftPos and 5 or 1
                local spacingStep = shiftPos and 0.5 or 0.1
                local headingStep = shiftPos and 15.0 or 1.0

                -- 1. Reposition Origin with Left Click
                if IsDisabledControlJustPressed(0, 24) then
                    local hit, hitPos = RayCastGamePlayCamera(50.0)
                    if hit == 1 then
                        grid.origin = hitPos
                        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                        changed = true
                    end
                end

                -- 2. Nudge Origin with WASD
                if IsControlJustPressed(0, 37) or IsDisabledControlJustPressed(0, 37) then -- TAB
                    gridMode = not gridMode
                    changed = true
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                end

                if gridMode then
                    local nudgeStep = shiftPos and 0.1 or 0.02
                    local dx, dy = 0.0, 0.0

                    if IsDisabledControlPressed(0, 32) then dy = dy + nudgeStep end -- W
                    if IsDisabledControlPressed(0, 33) then dy = dy - nudgeStep end -- S
                    if IsDisabledControlPressed(0, 34) then dx = dx - nudgeStep end -- A
                    if IsDisabledControlPressed(0, 35) then dx = dx + nudgeStep end -- D

                    if dx ~= 0.0 or dy ~= 0.0 then
                        local moveX, moveY = rotate(dx, dy, grid.heading)
                        grid.origin = vec3(grid.origin.x + moveX, grid.origin.y + moveY, grid.origin.z)
                        changed = true
                    end
                end

                -- 3. Manual Input via G
                if IsControlJustPressed(0, 47) then
                    -- Hide UI temporarily while input dialog is active
                    lib.hideTextUI()
                    local input = lib.inputDialog('Manual Grid Setup', {
                        { type = 'number', label = 'Rows', default = grid.rows, required = true, min = 1 },
                        { type = 'number', label = 'Cols', default = grid.cols, required = true, min = 1 },
                        { type = 'number', label = 'Spacing X', default = grid.spacing.x, required = true, min = 0.5, step = 0.1 },
                        { type = 'number', label = 'Spacing Y', default = grid.spacing.y, required = true, min = 0.5, step = 0.1 },
                        { type = 'number', label = 'Heading (degrees)', default = grid.heading, required = true, step = 0.1 }
                    })
                    
                    if input then
                        grid.rows = math.max(1, math.floor(input[1]))
                        grid.cols = math.max(1, math.floor(input[2]))
                        grid.spacing.x = input[3]
                        grid.spacing.y = input[4]
                        grid.heading = input[5] % 360.0
                        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                        changed = true
                    end
                    showInstructions()
                end
                
                -- 3. Arrow Keys
                if IsControlJustPressed(0, 172) then grid.rows = grid.rows + rowColStep; changed = true end
                if IsControlJustPressed(0, 173) then grid.rows = math.max(1, grid.rows - rowColStep); changed = true end
                if IsControlJustPressed(0, 175) then grid.cols = grid.cols + rowColStep; changed = true end
                if IsControlJustPressed(0, 174) then grid.cols = math.max(1, grid.cols - rowColStep); changed = true end
                
                -- 4. Scroll Wheel (with ALT for Y spacing)
                if IsControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 241) then
                    if altPos then grid.spacing.y = grid.spacing.y + spacingStep
                    else grid.spacing.x = grid.spacing.x + spacingStep end
                    changed = true
                end
                
                if IsControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 242) then
                    if altPos then grid.spacing.y = math.max(0.5, grid.spacing.y - spacingStep)
                    else grid.spacing.x = math.max(0.5, grid.spacing.x - spacingStep) end
                    changed = true
                end
                
                -- 5. Heading (Q/E)
                local pressQ = shiftPos and IsControlJustPressed(0, 44) or (not shiftPos and IsControlPressed(0, 44))
                local pressE = shiftPos and IsControlJustPressed(0, 38) or (not shiftPos and IsControlPressed(0, 38))
                
                if pressQ then grid.heading = (grid.heading + headingStep) % 360.0; changed = true end
                if pressE then grid.heading = (grid.heading - headingStep) % 360.0; changed = true end

                if changed then
                    showInstructions()
                end

                local slots = calculateGridSlots()
                for _, pos in ipairs(slots) do
                    DrawMarker(2, pos.x, pos.y, pos.z + 0.2, 0,0,0, 0,180.0,0, 0.2,0.2,0.2, 0,150,255,150, false, false, 2, false, nil, nil, false)
                end

                if IsControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 191) then -- 191 is ENTER (18 is removed to avoid Left Click conflict)
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    finalizeZone()
                end
            end

            -- Cancel
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then -- ESC or BACKSPACE
                state = STATE_IDLE
                lib.hideTextUI()
                Bridge.Notify("Zone Builder cancelled.", "error")
            end
        end
    end)
end

RegisterCommand('farm_builder', function()
    if state ~= STATE_IDLE then return end

    grid = {
        origin = nil,
        rows = 1,
        cols = 1,
        spacing = { x = 2.0, y = 2.0 },
        heading = 0.0
    }
    state = STATE_SELECT_ORIGIN
    gridMode = true
    showInstructions()
    startEditLoop()
end, false)
