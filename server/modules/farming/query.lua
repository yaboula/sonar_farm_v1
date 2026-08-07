--[[
    sonar_farm - Read-only queries (server)
    Lookups the client needs to render the world. Pure reads: no mutation, no
    inventory, no state changes. Kept apart from the action handlers so it is
    obvious that nothing here can be exploited into producing items.

    Stage 4 replaces this radius scan with spatial-cell subscriptions.
]]

local CALLBACKS = Sonar.Constants.CALLBACKS
local Utils = Sonar.Utils

-- Hard ceiling regardless of what the client asks for.
local MAX_RADIUS = 50.0

lib.callback.register(CALLBACKS.NEARBY, function(source, radius)
    local coords = Validation.GetPlayerCoords(source)
    if not coords then return {} end

    radius = math.min(tonumber(radius) or 20.0, MAX_RADIUS)

    local out = {}
    for _, record in pairs(State.All()) do
        local target = { x = record.pos_x, y = record.pos_y, z = record.pos_z }
        if Utils.IsWithin(coords, target, radius) then
            -- Evaluate (not Apply): a lookup must never mutate hot state.
            local condition = Physiology.Evaluate(record)
            out[#out + 1] = {
                cropId = record.id,
                cropType = record.crop_type,
                owner = record.owner,
                distance = Utils.Round(Utils.Distance(coords, target), 1),
                state = condition.state,
                progress = Utils.Round(condition.progress * 100, 0),
                water = condition.water,
                health = condition.health,
            }
        end
    end

    return out
end)
