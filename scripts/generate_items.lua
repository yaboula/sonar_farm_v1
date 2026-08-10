-- Generates the ox_inventory installation snapshot from shared/item_catalog.lua.

Sonar = {}
dofile('shared/item_catalog.lua')

local function quote(value)
    return string.format('%q', value)
end

local lines = {
    '-- GENERATED FILE - DO NOT EDIT.',
    '-- Source: shared/item_catalog.lua',
    '-- Run: lua scripts/generate_items.lua',
    '',
    'return {',
}

for _, item in ipairs(Sonar.ItemCatalog.items) do
    lines[#lines + 1] = ("    [%s] = {"):format(quote(item.id))
    lines[#lines + 1] = ("        label = %s,"):format(quote(item.label))
    lines[#lines + 1] = ("        weight = %d,"):format(item.weight)
    lines[#lines + 1] = ("        stack = %s,"):format(tostring(item.stack))
    lines[#lines + 1] = ("        close = %s,"):format(tostring(item.seed == true))
    lines[#lines + 1] = ("        description = %s,"):format(quote(item.description))
    if item.tool then
        lines[#lines + 1] = '        consume = 0,'
    end
    if item.seed then
        lines[#lines + 1] = '        client = {'
        lines[#lines + 1] = "            export = 'sonar_farm.useSeed',"
        lines[#lines + 1] = '        },'
    end
    lines[#lines + 1] = '    },'
    lines[#lines + 1] = ''
end

lines[#lines + 1] = '}'
lines[#lines + 1] = ''
local output = table.concat(lines, '\n')
local path = 'data/ox_inventory_items.lua'

local function effect(item)
    if item.tool and item.tool.action == 'weed' then
        local coverage = math.floor((item.tool.protectionCycleRatio or 0) * 100 + 0.5)
        if coverage > 0 then
            return ('Removes %d%% weeds | %d%% of crop cycle (%d uses)'):format(item.tool.weedRemoval, coverage, item.tool.uses)
        end
        return ('Removes %d%% weeds | %d uses'):format(item.tool.weedRemoval, item.tool.uses)
    end
    if item.tool and item.tool.action == 'water' then
        local coverage = math.floor((item.tool.protectionCycleRatio or 0) * 100 + 0.5)
        if coverage > 0 then
            return ('+%d%% water | %d%% of crop cycle (%d uses)'):format(item.tool.amount or 100, coverage, item.tool.uses)
        end
        return ('+%d%% water | %d uses'):format(item.tool.amount or 100, item.tool.uses)
    end
    if item.tool then return ('%d field uses'):format(item.tool.uses) end
    if not item.consumable then return item.description end
    local coverage = math.floor((item.consumable.protectionCycleRatio or 0) * 100 + 0.5)
    if item.consumable.action == 'fertilize' then
        return ('+%d nutrients | %d%% retention for %d%% of crop cycle'):format(item.consumable.amount,
            math.floor(item.consumable.protectionStrength * 100 + 0.5), coverage)
    end
    return ('-%d pest pressure | %d%% suppression for %d%% of crop cycle'):format(item.consumable.reduction,
        math.floor(item.consumable.protectionStrength * 100 + 0.5), coverage)
end

local web = {
    '// GENERATED FILE - DO NOT EDIT.',
    '// Source: shared/item_catalog.lua',
    '// Run: lua scripts/generate_items.lua',
    '',
    'import type { SupplyProduct } from "../types";',
    '',
    'export const CANONICAL_SUPPLY_PRODUCTS: SupplyProduct[] = [',
}
for _, item in ipairs(Sonar.ItemCatalog.market) do
    local stock = item.tier == 'plus' and '20' or item.tier == 'pro' and '10' or '"base"'
    local restock = item.tier == 'plus' and 'Restocks 5 every 30m'
        or item.tier == 'pro' and 'Restocks 2 every 60m' or 'Base supplier stock'
    local applications = item.tool and item.tool.uses or 1
    web[#web + 1] = ('  { id: %s, name: %s, category: %s, cropRelation: %s, detail: %s, effect: %s, tier: %s, image: %s, unit: "unit", unitPrice: %d, stock: %s, restock: %s, personalOwned: 0, companyOwned: 0, leadMinutes: %d, applications: %d },')
        :format(quote(item.id), quote(item.label), quote(item.category), quote(item.cropRelation),
            quote(item.description), quote(effect(item)), quote(item.tier), quote('assets/items/' .. item.id .. '.png'),
            item.price, stock, quote(restock), item.leadMinutes, applications)
end
web[#web + 1] = '];'
web[#web + 1] = ''
local webOutput = table.concat(web, '\n')
local webPath = 'web/src/data/itemCatalog.generated.ts'

local function verify(target, expected)
    local handle = assert(io.open(target, 'rb'))
    local current = handle:read('*a'):gsub('\r\n', '\n')
    handle:close()
    if current ~= expected then
        io.stderr:write(target .. ' is stale; run lua scripts/generate_items.lua\n')
        os.exit(1)
    end
    print(target .. ' is current')
end

local function write(target, value)
    local handle = assert(io.open(target, 'wb'))
    handle:write(value)
    handle:close()
    print('generated ' .. target)
end

if arg[1] == '--check' then
    verify(path, output)
    verify(webPath, webOutput)
    return
end

write(path, output)
write(webPath, webOutput)
