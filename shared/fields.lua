-- Pure compiler and validator for canonical Field definitions.

Sonar = Sonar or {}
Sonar.Fields = Sonar.Fields or {}
local Fields = Sonar.Fields

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function rotate(x, y, heading)
    local angle = math.rad(heading or 0)
    return x * math.cos(angle) - y * math.sin(angle), x * math.sin(angle) + y * math.cos(angle)
end

local function stableHash(value)
    local hash = 2166136261
    for index = 1, #value do
        hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff
    end
    return ('%08x'):format(hash)
end

local function stableValue(value)
    if type(value) ~= 'table' then return tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local output = {}
    for _, key in ipairs(keys) do output[#output + 1] = tostring(key) .. '=' .. stableValue(value[key]) end
    return '{' .. table.concat(output, ',') .. '}'
end

local function rawRows(definition)
    if definition.grid then
        local grid, rows = definition.grid, {}
        local rowCount = math.floor(tonumber(grid.rows) or 0)
        local columnCount = math.floor(tonumber(grid.cols) or 0)
        local spacingX = type(grid.spacing) == 'table' and tonumber(grid.spacing.x) or 0
        local spacingY = type(grid.spacing) == 'table' and tonumber(grid.spacing.y) or 0
        spacingX, spacingY = spacingX or 0, spacingY or 0
        local origin = type(grid.origin) == 'table' and grid.origin or {}
        local offsetX, offsetY = ((columnCount - 1) * spacingX) / 2, ((rowCount - 1) * spacingY) / 2
        for rowIndex = 1, rowCount do
            local row = { slots = {} }
            for columnIndex = 1, columnCount do
                local dx, dy = rotate(((columnIndex - 1) * spacingX) - offsetX,
                    ((rowIndex - 1) * spacingY) - offsetY, grid.heading)
                row.slots[#row.slots + 1] = { x = (tonumber(origin.x) or 0) + dx,
                    y = (tonumber(origin.y) or 0) + dy,
                    z = tonumber(origin.z), heading = tonumber(grid.heading) or 0 }
            end
            rows[#rows + 1] = row
        end
        return rows
    end
    return definition.rows or {}
end

function Fields.ValidateDefinition(definition)
    local errors = {}
    if type(definition) ~= 'table' then return { 'definition must be a table' } end
    if type(definition.id) ~= 'string' or not definition.id:match('^[%w_%-]+$') then errors[#errors + 1] = 'invalid field id' end
    if type(definition.name) ~= 'string' or definition.name == '' then errors[#errors + 1] = 'field name is required' end
    if type(definition.access) ~= 'table' or not finite(definition.access.x)
        or not finite(definition.access.y) or not finite(definition.access.z) then
        errors[#errors + 1] = 'field access coordinates are invalid'
    end
    if definition.grid then
        local grid = definition.grid
        if type(grid.origin) ~= 'table' or not finite(grid.origin.x) or not finite(grid.origin.y)
            or not finite(grid.origin.z) then errors[#errors + 1] = 'grid origin is invalid' end
        if type(grid.spacing) ~= 'table' or not finite(grid.spacing.x) or not finite(grid.spacing.y)
            or grid.spacing.x <= 0 or grid.spacing.y <= 0 then errors[#errors + 1] = 'grid spacing must be positive' end
    end
    local rows = rawRows(definition)
    if #rows < 1 or #rows > 20 then errors[#errors + 1] = 'field must contain 1..20 rows' end
    local count, seen, positions = 0, {}, {}
    for rowIndex, row in ipairs(rows) do
        if type(row.slots) ~= 'table' or #row.slots < 2 or #row.slots > 20 then
            errors[#errors + 1] = ('row %d must contain 2..20 slots'):format(rowIndex)
        end
        for slotIndex, slot in ipairs(row.slots or {}) do
            count = count + 1
            if not finite(slot.x) or not finite(slot.y) or not finite(slot.z) or not finite(slot.heading or 0) then
                errors[#errors + 1] = ('row %d slot %d has invalid coordinates'):format(rowIndex, slotIndex)
            else
                local coordinateKey = ('%.3f:%.3f:%.3f'):format(slot.x, slot.y, slot.z)
                if seen[coordinateKey] then errors[#errors + 1] = ('duplicate slot coordinates at row %d slot %d'):format(rowIndex, slotIndex) end
                seen[coordinateKey] = true
                local minimum = Config.Fields and tonumber(Config.Fields.MinimumSlotSpacing) or 0.75
                for _, other in ipairs(positions) do
                    local dx, dy, dz = slot.x - other.x, slot.y - other.y, slot.z - other.z
                    if math.sqrt(dx * dx + dy * dy + dz * dz) < minimum then
                        errors[#errors + 1] = ('row %d slot %d is closer than %.2fm to another slot'):format(rowIndex, slotIndex, minimum)
                        break
                    end
                end
                positions[#positions + 1] = slot
            end
        end
    end
    if count > 400 then errors[#errors + 1] = 'field exceeds 400 slots' end
    for _, crop in ipairs(definition.allowedCrops or {}) do
        if not Config.Crops[crop] then errors[#errors + 1] = 'unknown allowed crop ' .. tostring(crop) end
    end
    return errors
end

function Fields.Compile(definition)
    local errors = Fields.ValidateDefinition(definition)
    if #errors > 0 then return nil, errors end
    local rows, minX, maxX, minY, maxY = rawRows(definition), math.huge, -math.huge, math.huge, -math.huge
    for _, row in ipairs(rows) do
        for _, slot in ipairs(row.slots) do
            minX, maxX, minY, maxY = math.min(minX, slot.x), math.max(maxX, slot.x), math.min(minY, slot.y), math.max(maxY, slot.y)
        end
    end
    local width, height, legacyIndex = math.max(0.01, maxX - minX), math.max(0.01, maxY - minY), 0
    local compiled = {
        id = definition.id, legacyZone = definition.legacyZone, name = definition.name, location = definition.location,
        orientation = definition.orientation or 0, starterEligible = definition.starterEligible == true,
        starterPriority = tonumber(definition.starterPriority) or 999, purchasePrice = tonumber(definition.purchasePrice) or 0,
        catalogVisible = definition.catalogVisible ~= false, allowedCrops = definition.allowedCrops or {},
        access = definition.access, blip = definition.blip, bounds = { width = width, height = height }, rows = {}, slots = {},
    }
    for rowIndex, row in ipairs(rows) do
        local rowId = ('%s:row:%02d'):format(definition.id, rowIndex)
        local outputRow = { id = rowId, label = ('Row %d'):format(rowIndex), order = rowIndex, slotIds = {} }
        for slotIndex, slot in ipairs(row.slots) do
            legacyIndex = legacyIndex + 1
            local slotId = ('%s:slot:%03d'):format(definition.id, legacyIndex)
            local outputSlot = { id = slotId, rowId = rowId, order = slotIndex, legacyIndex = legacyIndex,
                x = slot.x, y = slot.y, z = slot.z, heading = slot.heading or 0,
                position = { x = (slot.x - minX) / width, y = (slot.y - minY) / height } }
            outputRow.slotIds[#outputRow.slotIds + 1] = slotId
            compiled.slots[#compiled.slots + 1] = outputSlot
        end
        compiled.rows[#compiled.rows + 1] = outputRow
    end
    compiled.checksum = stableHash(stableValue(compiled))
    return compiled, {}
end

function Fields.CompileSeeds()
    local fields, errors, ids = {}, {}, {}
    for _, definition in ipairs(Config.FieldSeeds or {}) do
        local field, fieldErrors = Fields.Compile(definition)
        if field and ids[field.id] then errors[#errors + 1] = ('%s: duplicate field id'):format(field.id)
        elseif field then fields[#fields + 1], ids[field.id] = field, true else
            for _, message in ipairs(fieldErrors) do errors[#errors + 1] = ('%s: %s'):format(tostring(definition.id), message) end
        end
    end
    local minimum = Config.Fields and tonumber(Config.Fields.MinimumSlotSpacing) or 0.75
    for left = 1, #fields do
        for right = left + 1, #fields do
            local collision = false
            for _, a in ipairs(fields[left].slots) do
                for _, b in ipairs(fields[right].slots) do
                    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
                    if math.sqrt(dx * dx + dy * dy + dz * dz) < minimum then collision = true; break end
                end
                if collision then break end
            end
            if collision then errors[#errors + 1] = ('%s overlaps %s'):format(fields[left].id, fields[right].id) end
        end
    end
    return fields, errors
end
