--[[
    sonar_farm - Zone blips (client)
    Map markers for the public farming zones. A player who cannot find where to
    plant abandons the activity, so this is on by default; each zone can opt out
    in config/zones.lua.

    Created once at boot. Blips cost nothing per frame.
]]

local blips = {}

CreateThread(function()
    for _, zone in pairs(Config.Zones or {}) do
        local cfg = zone.blip
        if cfg and cfg.enabled then
            local blip = AddBlipForCoord(zone.center.x, zone.center.y, zone.center.z)

            SetBlipSprite(blip, cfg.sprite or 496)
            SetBlipColour(blip, cfg.color or 25)
            SetBlipScale(blip, cfg.scale or 0.8)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(zone.label or 'Farming Zone')
            EndTextCommandSetBlipName(blip)

            blips[#blips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)
