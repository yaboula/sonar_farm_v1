--[[
    sonar_farm - Bridge wrapper: ox_target
    Client-side wrapper over ox_target exports. Populates Bridge.Target.
    Used by the interaction layer (Stage 4+) to attach options to crops/zones.
]]

if IsDuplicityVersion() then
    -- ox_target is a client-side concern. Nothing to expose on the server.
    return
end

local target = exports.ox_target

--- Add a box zone interaction.
---@param options table ox_target box zone options (coords, size, rotation, options).
---@return number|string id Zone handle for later removal.
function Bridge.Target.AddBoxZone(options)
    return target:addBoxZone(options)
end

--- Add a sphere zone interaction. Matches how farming zones are configured
--- (center + radius), unlike a box zone which would need a size vector.
---@param options table ox_target sphere zone options (coords, radius, options).
---@return number|string id Zone handle for later removal.
function Bridge.Target.AddSphereZone(options)
    return target:addSphereZone(options)
end

--- Add interaction options to a specific local (client-side) entity.
---@param entity number Entity handle.
---@param options table Array of ox_target option tables.
function Bridge.Target.AddLocalEntity(entity, options)
    return target:addLocalEntity(entity, options)
end

--- Remove a previously added zone by its handle.
---@param id number|string
function Bridge.Target.RemoveZone(id)
    return target:removeZone(id)
end

--- Remove interaction options from a local entity.
---@param entity number
---@param optionNames? string|string[]
function Bridge.Target.RemoveLocalEntity(entity, optionNames)
    return target:removeLocalEntity(entity, optionNames)
end
