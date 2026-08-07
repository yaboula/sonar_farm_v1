--[[
    sonar_farm - Crop interaction (client)
    Attaches ox_target options to crop props. The interaction lifecycle is bound
    to the prop's lifecycle: one source of truth for "exists visually" and "is
    interactable".

    Two deliberate choices:
      - Interaction distance sits below Security.MaxInteractDistance, so if
        ox_target lets a player click, the server will not reject for distance.
        A `too_far` rejection then means what it should: an exploit attempt.
      - Options are filtered with canInteract from the locally derived condition.
        This is convenience only; the server validates everything regardless.

    The crop id is captured in the option closures rather than looked up from the
    entity handle. Props are destroyed and re-created on every stage change, so
    the closure is always bound to the right crop, and canInteract (which runs
    while the player looks at a prop) stays free of any lookup.

    Empty planting plots are handled separately in client/modules/zones/slots.lua.
]]

Target = Target or {}

local CROP_STATE = Sonar.Constants.CROP_STATE

--- Human-readable condition summary for the inspect option.
---@param cropId string
---@return string
local function describe(cropId)
    local record = Crops.Get(cropId)
    local condition = Crops.Condition(cropId)
    if not record or not condition then return 'Unknown crop.' end

    local def = Config.Crops and Config.Crops[record.crop_type]
    local label = (def and def.label) or record.crop_type

    if condition.state == CROP_STATE.DEAD then
        return ('%s: dead. Harvest to clear the plot.'):format(label)
    end

    if condition.progress >= 1 then
        return ('%s: ready to harvest. Health %d%%.'):format(label, math.floor(condition.health))
    end

    return ('%s: %d%% grown. Water %d%%, health %d%%.')
        :format(label, math.floor(condition.progress * 100), math.floor(condition.water), math.floor(condition.health))
end

--- Attach interaction options to a crop prop.
---@param entity number
---@param cropId string
function Target.Attach(entity, cropId)
    local distance = Config.Render.TargetDistance

    Bridge.Target.AddLocalEntity(entity, {
        {
            name = 'sonar_farm:harvest',
            label = 'Harvest',
            icon = 'fa-solid fa-wheat-awn',
            distance = distance,
            onSelect = function()
                Actions.Harvest(cropId)
            end,
            canInteract = function()
                local condition = Crops.Condition(cropId)
                if not condition then return false end
                -- A dead crop stays selectable: harvesting clears the plot.
                return condition.progress >= 1 or condition.state == CROP_STATE.DEAD
            end,
        },
        {
            name = 'sonar_farm:water',
            label = 'Water',
            icon = 'fa-solid fa-droplet',
            distance = distance,
            onSelect = function()
                Actions.Water(cropId)
            end,
            canInteract = function()
                local condition = Crops.Condition(cropId)
                if not condition then return false end
                if condition.state == CROP_STATE.DEAD then return false end
                return condition.water < Config.Farming.WaterRefillThreshold
            end,
        },
        {
            name = 'sonar_farm:inspect',
            label = 'Inspect',
            icon = 'fa-solid fa-magnifying-glass',
            distance = distance,
            onSelect = function()
                Bridge.Notify(describe(cropId), Sonar.Constants.NOTIFY.INFO)
            end,
        },
    })
end

--- Remove interaction options from a prop that is about to be destroyed.
--- ox_target cleans up deleted entities on its own; doing it explicitly keeps the
--- two lifecycles in lockstep instead of relying on that.
---@param entity number
function Target.Detach(entity)
    if not entity or not DoesEntityExist(entity) then return end
    Bridge.Target.RemoveLocalEntity(entity, {
        'sonar_farm:harvest',
        'sonar_farm:water',
        'sonar_farm:inspect',
    })
end

--- Crop keys plantable in a zone, for the plant menu.
---@param zoneKey string
---@return string[]
function Target.AllowedCrops(zoneKey)
    return Sonar.Zones.AllowedCrops(zoneKey)
end
