-- sonar_farm - Dependency-free Lua regression suite.

local passed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        io.stderr:write(('FAIL %s: %s\n'):format(name, tostring(err)))
        os.exit(1)
    end
    passed = passed + 1
    print(('PASS %s'):format(name))
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(('%s (expected %s, got %s)'):format(message or 'values differ', tostring(expected), tostring(actual)))
    end
end

-- Minimal FiveM/ox environment used by shared and server-pure modules.
function vec3(x, y, z) return { x = x, y = y, z = z } end
function GetCurrentResourceName() return 'sonar_farm' end
function IsDuplicityVersion() return true end
function GetNetworkTimeAccurate() return os.time() * 1000 end
function AddEventHandler() end
function GetPlayerPed() return 1 end
function GetEntityCoords() return vec3(2236.0, 5031.0, 44.2) end
function GetPlayerRoutingBucket() return 0 end

local gameTimer = 1000
function GetGameTimer() return gameTimer end

json = {
    encode = function() return '{}' end,
    decode = function() return {} end,
}

Logger = {
    Info = function() end,
    Warn = function() end,
    Exploit = function() end,
}

Bridge = {
    Ready = true,
    GetIdentifier = function() return 'citizen-test' end,
    GetPlayerName = function() return 'Test Player' end,
    Inventory = { HasItem = function() return true end },
}

dofile('config/config.lua')
dofile('config/crops.lua')
dofile('config/zones.lua')
dofile('config/minigames.lua')
dofile('shared/constants.lua')
dofile('shared/utils.lua')
dofile('shared/time.lua')
dofile('shared/growth.lua')
dofile('shared/physiology.lua')
dofile('shared/zones.lua')
dofile('shared/config_validation.lua')

test('production config validates', function()
    local errors = Sonar.ConfigValidation.Validate()
    equal(#errors, 0, table.concat(errors, '; '))
end)

test('invalid operational config is rejected', function()
    local ace = Config.Admin.Ace
    local buckets = Config.Security.AllowedRoutingBuckets
    Config.Admin.Ace = ''
    Config.Security.AllowedRoutingBuckets = { -1 }

    local errors = Sonar.ConfigValidation.Validate()
    assert(#errors >= 2, 'admin ACE and routing bucket errors expected')

    Config.Admin.Ace = ace
    Config.Security.AllowedRoutingBuckets = buckets
end)

test('malformed crop config reports an error instead of crashing validation', function()
    local stage = Config.Crops.carrot.stages[1]
    Config.Crops.carrot.stages[1] = 'invalid'

    local ok, errors = pcall(Sonar.ConfigValidation.Validate)
    equal(ok, true, 'validator must not crash')
    assert(#errors > 0, 'malformed crop must be rejected')

    Config.Crops.carrot.stages[1] = stage
end)

test('zone grids and explicit slots resolve', function()
    equal(Sonar.Zones.Count('grapeseed_east'), 40, 'east slot count')
    equal(Sonar.Zones.Count('grapeseed_south'), 24, 'south slot count')
    equal(Sonar.Zones.Count('zone1'), 24, 'explicit slot count')
    equal(Sonar.Zones.Slot('zone1', 1).zone, 'zone1', 'slot zone')
end)

test('growth is timestamp based and clamped', function()
    local record = {
        crop_type = 'carrot',
        planted_at = 1000,
        growth_time = 100,
        data = {},
    }
    equal(Growth.Evaluate(record, 1050).progress, 0.5, 'half growth')
    equal(Growth.Evaluate(record, 1200).state, Sonar.Constants.CROP_STATE.MATURE, 'mature state')
end)

test('physiology derives drought and spoilage without mutation', function()
    local record = {
        crop_type = 'lettuce',
        planted_at = 1000,
        growth_time = 100,
        data = { water = 0, health = 100, spoilage = 0, lastCare = 1000 },
    }
    local condition = Physiology.Evaluate(record, 4600)
    assert(condition.health < 100, 'dry crop should lose health')
    assert(condition.spoilage > 0, 'mature crop should spoil')
    equal(record.data.health, 100, 'evaluation must be pure')
end)

Database = {
    LoadAllCrops = function() return {} end,
    UpsertCrops = function() return true end,
    DeleteCrops = function() return true end,
}

dofile('server/modules/state/state.lua')

test('state keeps cell, owner and slot indexes consistent', function()
    Sonar.Utils.SeedRandom(1234, 5678)
    local id, record = State.Add({
        crop_type = 'carrot',
        owner = 'owner-a',
        zone = 'grapeseed_east',
        slot = 1,
        pos_x = 2236.0,
        pos_y = 5031.0,
        pos_z = 44.2,
    })
    equal(#id, 36, 'UUID length')
    equal(State.CountByOwner('owner-a'), 1, 'owner index')
    equal(State.SlotOccupant('grapeseed_east', 1), id, 'slot index')

    State.Update(id, { owner = 'owner-b', pos_x = 2000.0 })
    equal(State.CountByOwner('owner-a'), 0, 'old owner removed')
    equal(State.CountByOwner('owner-b'), 1, 'new owner added')
    equal(record.cell, State.CellKey(2000.0, record.pos_y), 'cell reindexed')

    State.Remove(id)
    equal(State.Count(), 0, 'crop removed')
    equal(State.SlotOccupant('grapeseed_east', 1), nil, 'slot released')
end)

test('state load fails closed on database errors', function()
    Database.LoadAllCrops = function() return nil, 'database unavailable' end
    local ok, err = State.LoadAll()
    equal(ok, false, 'load must fail')
    assert(tostring(err):find('database unavailable', 1, true), 'database error must propagate')
end)

test('state load rejects invalid persisted growth data', function()
    Database.LoadAllCrops = function()
        return {
            {
                id = '00000000-0000-4000-8000-000000000099',
                crop_type = 'carrot',
                pos_x = 2236.0,
                pos_y = 5031.0,
                pos_z = 44.2,
                planted_at = 1000,
                growth_time = 0,
            },
        }
    end
    local ok = State.LoadAll()
    equal(ok, false, 'invalid row must fail boot')
    equal(State.loaded, false, 'state remains unavailable')
end)

test('state load repairs stale spatial cells', function()
    Database.LoadAllCrops = function()
        return {
            {
                id = '00000000-0000-4000-8000-000000000001',
                crop_type = 'carrot',
                owner = 'owner-a',
                zone = 'grapeseed_east',
                slot = 1,
                cell = 'stale',
                pos_x = 2236.0,
                pos_y = 5031.0,
                pos_z = 44.2,
                planted_at = 1000,
                growth_time = 900,
                data = nil,
            },
        }
    end
    local ok, loaded = State.LoadAll()
    equal(ok, true, 'load should succeed')
    equal(loaded, 1, 'loaded count')
    equal(State.Get('00000000-0000-4000-8000-000000000001').cell, State.CellKey(2236.0, 5031.0), 'cell repaired')
    equal(State.dirty['00000000-0000-4000-8000-000000000001'], true, 'repair queued')
end)

dofile('server/modules/farming/lock.lua')

test('locks reject concurrent acquisition and release after errors', function()
    equal(Lock.Acquire('crop'), true, 'first lock')
    equal(Lock.Acquire('crop'), false, 'second lock')
    Lock.Release('crop')
    local ok = pcall(function()
        Lock.With('crop', function() error('expected') end)
    end)
    equal(ok, false, 'error propagated')
    equal(Lock.Acquire('crop'), true, 'lock released after error')
    Lock.Release('crop')
end)

dofile('server/modules/runtime/runtime.lua')

test('runtime gate enforces lifecycle, bucket and identifier', function()
    Runtime.SetStatus(Runtime.STATUS.BOOTING)
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.SERVICE_UNAVAILABLE, 'boot gate')

    Runtime.SetStatus(Runtime.STATUS.READY)
    equal(Runtime.GuardPlayer(1).ok, true, 'ready player')

    local originalBucket = GetPlayerRoutingBucket
    GetPlayerRoutingBucket = function() return 99 end
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.WRONG_INSTANCE, 'bucket gate')
    GetPlayerRoutingBucket = originalBucket

    local originalIdentifier = Bridge.GetIdentifier
    Bridge.GetIdentifier = function() return nil end
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.PLAYER_NOT_READY, 'identifier gate')
    Bridge.GetIdentifier = originalIdentifier
end)

dofile('server/modules/security/ratelimit.lua')

test('rate limit scopes are independent and refill lazily', function()
    Security.Release(1)
    for _ = 1, Config.Security.SubscriptionBucket.capacity do
        equal(Security.Consume(1, 1, 'subscribe'), true, 'subscription token')
    end
    equal(Security.Consume(1, 1, 'subscribe'), false, 'subscription limited')
    equal(Security.Consume(1, 1, 'action'), true, 'action scope unaffected')
    gameTimer = gameTimer + 1000
    equal(Security.Consume(1, 1, 'subscribe'), true, 'subscription refilled')
end)

test('database serializes nullable slots without nil parameter holes', function()
    local captured
    MySQL = {
        transaction = {
            await = function(queries)
                captured = queries
                return true
            end,
        },
    }

    dofile('server/modules/database/database.lua')
    local ok = Database.UpsertCrops({
        {
            id = '00000000-0000-4000-8000-000000000002',
            crop_type = 'carrot',
            cell = '1:1',
            pos_x = 1,
            pos_y = 2,
            pos_z = 3,
            planted_at = 1000,
            growth_time = 900,
        },
    })

    equal(ok, true, 'upsert succeeds')
    assert(captured[1].query:find('NULLIF%(%?, 0%)'), 'numeric NULLIF placeholder')
    equal(captured[1].values[5], 0, 'slot sentinel')
    equal(#captured[1].values, 14, 'dense parameter array')
end)

test('database rejects an empty but incompatible schema', function()
    local columns = {
        'id', 'crop_type', 'owner', 'zone', 'slot', 'cell',
        'pos_x', 'pos_y', 'pos_z', 'heading',
        'planted_at', 'growth_time', 'state', 'data',
    }

    MySQL.query = {
        await = function(sql)
            if sql:find('information_schema.COLUMNS', 1, true) then
                local rows = {}
                for _, name in ipairs(columns) do
                    rows[#rows + 1] = { COLUMN_NAME = name }
                end
                return rows
            end
            return {
                { COLUMN_NAME = 'zone', NON_UNIQUE = 0, SEQ_IN_INDEX = 1 },
                { COLUMN_NAME = 'slot', NON_UNIQUE = 0, SEQ_IN_INDEX = 2 },
            }
        end,
    }

    equal(Database.ValidateSchema(), true, 'complete schema')
    table.remove(columns)
    equal(Database.ValidateSchema(), false, 'missing data column')
end)

print(('All %d tests passed.'):format(passed))
